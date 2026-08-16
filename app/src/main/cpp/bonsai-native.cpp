#include <jni.h>
#include <string>
#include <vector>
#include <android/log.h>
#include "llama.h"

#define TAG "BonsaiNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)

struct BonsaiContext {
    llama_model * model = nullptr;
    llama_context * ctx = nullptr;
    const llama_vocab * vocab = nullptr;
    llama_context_params params;
};

extern "C" {

JNIEXPORT jlong JNICALL
Java_com_aga_tinol_BonsaiNative_loadModel(JNIEnv *env, jclass clazz, jstring model_path, jint n_threads, jint n_ctx, jint n_batch) {
    const char *path = env->GetStringUTFChars(model_path, nullptr);
    LOGI("Loading model from: %s (ctx: %d, batch: %d)", path, n_ctx, n_batch);

    llama_backend_init();

    auto mparams = llama_model_default_params();
    mparams.use_mmap = false; // Disable mmap for better stability on some emulators/devices
    llama_model * model = llama_model_load_from_file(path, mparams);

    if (!model) {
        LOGE("Failed to load model from %s", path);
        env->ReleaseStringUTFChars(model_path, path);
        return 0;
    }

    auto cparams = llama_context_default_params();
    cparams.n_threads = n_threads;
    cparams.n_threads_batch = n_threads;
    cparams.n_ctx = n_ctx;
    cparams.n_batch = n_batch;

    llama_context * ctx = llama_init_from_model(model, cparams);
    if (!ctx) {
        LOGE("Failed to create context");
        llama_model_free(model);
        env->ReleaseStringUTFChars(model_path, path);
        return 0;
    }

    BonsaiContext * bctx = new BonsaiContext();
    bctx->model = model;
    bctx->ctx = ctx;
    bctx->vocab = llama_model_get_vocab(model);
    bctx->params = cparams;

    env->ReleaseStringUTFChars(model_path, path);
    return reinterpret_cast<jlong>(bctx);
}

JNIEXPORT void JNICALL
Java_com_aga_tinol_BonsaiNative_freeModel(JNIEnv *env, jclass clazz, jlong handle) {
    if (handle == 0) return;
    BonsaiContext * bctx = reinterpret_cast<BonsaiContext *>(handle);
    if (bctx) {
        if (bctx->ctx) llama_free(bctx->ctx);
        if (bctx->model) llama_model_free(bctx->model);
        delete bctx;
        llama_backend_free();
        LOGI("Model resources freed");
    }
}

JNIEXPORT jintArray JNICALL
Java_com_aga_tinol_BonsaiNative_tokenize(JNIEnv *env, jclass clazz, jlong handle, jstring prompt,
                                         jboolean add_bos) {
    if (handle == 0) return env->NewIntArray(0);
    BonsaiContext * bctx = reinterpret_cast<BonsaiContext *>(handle);
    const char *text = env->GetStringUTFChars(prompt, nullptr);

    std::vector<llama_token> tokens(strlen(text) + (add_bos ? 1 : 0));
    int n_tokens = llama_tokenize(bctx->vocab, text, strlen(text), tokens.data(), tokens.size(), add_bos, false);

    if (n_tokens < 0) {
        tokens.resize(-n_tokens);
        n_tokens = llama_tokenize(bctx->vocab, text, strlen(text), tokens.data(), tokens.size(), add_bos, false);
    }

    jintArray result = env->NewIntArray(n_tokens);
    env->SetIntArrayRegion(result, 0, n_tokens, (const jint *)tokens.data());

    env->ReleaseStringUTFChars(prompt, text);
    return result;
}

JNIEXPORT void JNICALL
Java_com_aga_tinol_BonsaiNative_generate(JNIEnv *env, jclass clazz, jlong handle, jintArray input_tokens,
                                         jint max_tokens, jfloat top_p, jfloat temp, jint top_k,
                                         jobject callback) {
    if (handle == 0) return;
    BonsaiContext * bctx = reinterpret_cast<BonsaiContext *>(handle);
    jsize n_input = env->GetArrayLength(input_tokens);
    jint * tokens_ptr = env->GetIntArrayElements(input_tokens, nullptr);

    std::vector<llama_token> tokens_list;
    for (int i = 0; i < n_input; ++i) tokens_list.push_back(tokens_ptr[i]);
    env->ReleaseIntArrayElements(input_tokens, tokens_ptr, JNI_ABORT);

    jclass callbackClass = env->GetObjectClass(callback);
    jmethodID onTokenMethod = env->GetMethodID(callbackClass, "onToken", "(I)Z");

    // Fix: Initialize batch with the actual number of tokens to avoid overflow
    int32_t n_tokens = (int32_t)tokens_list.size();
    // Completely reset context for each prompt to bypass KV cache issues in this branch
    if (bctx->ctx) {
        llama_free(bctx->ctx);
        bctx->ctx = llama_init_from_model(bctx->model, bctx->params);
    }

    if (!bctx->ctx) {
        LOGE("Failed to re-initialize context");
        return;
    }

    llama_batch batch = llama_batch_init(n_tokens, 0, 1);

    for (int i = 0; i < n_tokens; ++i) {
        batch.token[batch.n_tokens] = tokens_list[i];
        batch.pos[batch.n_tokens] = i;
        batch.n_seq_id[batch.n_tokens] = 1;
        batch.seq_id[batch.n_tokens][0] = 0;
        batch.logits[batch.n_tokens] = (i == n_tokens - 1);
        batch.n_tokens++;
    }

    if (llama_decode(bctx->ctx, batch) != 0) {
        LOGE("llama_decode failed during prompt processing");
        llama_batch_free(batch);
        return;
    }
    llama_batch_free(batch); // Free prompt batch after decode

    // Set up sampling chain with user parameters
    llama_sampler_chain_params sparams = { .no_perf = true };
    struct llama_sampler * smpl = llama_sampler_chain_init(sparams);
    llama_sampler_chain_add(smpl, llama_sampler_init_top_k(top_k));
    llama_sampler_chain_add(smpl, llama_sampler_init_top_p(top_p, 1));
    llama_sampler_chain_add(smpl, llama_sampler_init_temp(temp));
    llama_sampler_chain_add(smpl, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

    int n_cur = tokens_list.size();
    int n_gen = 0;

    while (n_gen < max_tokens) {
        const llama_token new_token_id = llama_sampler_sample(smpl, bctx->ctx, -1);
        llama_sampler_accept(smpl, new_token_id);

        if (llama_vocab_is_eog(bctx->vocab, new_token_id)) break;

        jboolean should_continue = env->CallBooleanMethod(callback, onTokenMethod, (jint)new_token_id);
        if (!should_continue) break;

        // Use a single-token batch for generation
        llama_batch g_batch = llama_batch_init(1, 0, 1);
        g_batch.token[0]    = new_token_id;
        g_batch.pos[0]      = n_cur;
        g_batch.n_seq_id[0] = 1;
        g_batch.seq_id[0][0] = 0;
        g_batch.logits[0]   = true;
        g_batch.n_tokens    = 1;
        
        if (llama_decode(bctx->ctx, g_batch) != 0) {
            LOGE("llama_decode failed during generation");
            llama_batch_free(g_batch);
            break;
        }
        llama_batch_free(g_batch);

        n_cur++;
        n_gen++;
    }
    llama_sampler_free(smpl);
}

JNIEXPORT jstring JNICALL
Java_com_aga_tinol_BonsaiNative_tokenToString(JNIEnv *env, jclass clazz, jlong handle, jint token_id) {
    if (handle == 0) return env->NewStringUTF("");
    BonsaiContext * bctx = reinterpret_cast<BonsaiContext *>(handle);
    std::vector<char> result(128);
    int n = llama_token_to_piece(bctx->vocab, (llama_token)token_id, result.data(), result.size(), 0, false);
    if (n < 0) {
        result.resize(-n);
        n = llama_token_to_piece(bctx->vocab, (llama_token)token_id, result.data(), result.size(), 0, false);
    }
    result.resize(n);
    return env->NewStringUTF(std::string(result.begin(), result.end()).c_str());
}

}
