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
};

extern "C" {

JNIEXPORT jlong JNICALL
Java_com_aga_tinol_BonsaiNative_loadModel(JNIEnv *env, jclass clazz, jstring model_path, jint n_threads) {
    const char *path = env->GetStringUTFChars(model_path, nullptr);
    LOGI("Loading model from: %s", path);

    llama_backend_init();

    auto mparams = llama_model_default_params();
    llama_model * model = llama_load_model_from_file(path, mparams);

    if (!model) {
        LOGE("Failed to load model from %s", path);
        env->ReleaseStringUTFChars(model_path, path);
        return 0;
    }

    auto cparams = llama_context_default_params();
    cparams.n_threads = n_threads;
    cparams.n_threads_batch = n_threads;

    llama_context * ctx = llama_new_context_with_model(model, cparams);
    if (!ctx) {
        LOGE("Failed to create context");
        llama_free_model(model);
        env->ReleaseStringUTFChars(model_path, path);
        return 0;
    }

    BonsaiContext * bctx = new BonsaiContext();
    bctx->model = model;
    bctx->ctx = ctx;

    env->ReleaseStringUTFChars(model_path, path);
    return reinterpret_cast<jlong>(bctx);
}

JNIEXPORT void JNICALL
Java_com_aga_tinol_BonsaiNative_freeModel(JNIEnv *env, jclass clazz, jlong handle) {
    BonsaiContext * bctx = reinterpret_cast<BonsaiContext *>(handle);
    if (bctx) {
        if (bctx->ctx) llama_free(bctx->ctx);
        if (bctx->model) llama_free_model(bctx->model);
        delete bctx;
        llama_backend_free();
        LOGI("Model resources freed");
    }
}

JNIEXPORT jintArray JNICALL
Java_com_aga_tinol_BonsaiNative_tokenize(JNIEnv *env, jclass clazz, jlong handle, jstring prompt,
                                         jboolean add_bos) {
    BonsaiContext * bctx = reinterpret_cast<BonsaiContext *>(handle);
    const char *text = env->GetStringUTFChars(prompt, nullptr);

    std::vector<llama_token> tokens(strlen(text) + (add_bos ? 1 : 0));
    int n_tokens = llama_tokenize(bctx->model, text, strlen(text), tokens.data(), tokens.size(), add_bos, false);

    if (n_tokens < 0) {
        tokens.resize(-n_tokens);
        n_tokens = llama_tokenize(bctx->model, text, strlen(text), tokens.data(), tokens.size(), add_bos, false);
    }

    jintArray result = env->NewIntArray(n_tokens);
    env->SetIntArrayRegion(result, 0, n_tokens, (const jint *)tokens.data());

    env->ReleaseStringUTFChars(prompt, text);
    return result;
}

JNIEXPORT void JNICALL
Java_com_aga_tinol_BonsaiNative_generate(JNIEnv *env, jclass clazz, jlong handle, jintArray input_tokens,
                                         jint max_tokens, jfloat top_p, jfloat temp,
                                         jobject callback) {
    BonsaiContext * bctx = reinterpret_cast<BonsaiContext *>(handle);
    jsize n_input = env->GetArrayLength(input_tokens);
    jint * tokens_ptr = env->GetIntArrayElements(input_tokens, nullptr);

    std::vector<llama_token> tokens_list;
    for (int i = 0; i < n_input; ++i) tokens_list.push_back(tokens_ptr[i]);
    env->ReleaseIntArrayElements(input_tokens, tokens_ptr, JNI_ABORT);

    jclass callbackClass = env->GetObjectClass(callback);
    jmethodID onTokenMethod = env->GetMethodID(callbackClass, "onToken", "(I)Z");

    llama_batch batch = llama_batch_init(512, 0, 1);

    for (int i = 0; i < tokens_list.size(); ++i) {
        batch.token[batch.n_tokens] = tokens_list[i];
        batch.pos[batch.n_tokens] = i;
        batch.n_seq_id[batch.n_tokens] = 1;
        batch.seq_id[batch.n_tokens][0] = 0;
        batch.logits[batch.n_tokens] = (i == tokens_list.size() - 1);
        batch.n_tokens++;
    }

    if (llama_decode(bctx->ctx, batch) != 0) {
        LOGE("llama_decode failed");
        llama_batch_free(batch);
        return;
    }

    int n_cur = tokens_list.size();
    int n_gen = 0;

    while (n_gen < max_tokens) {
        auto logits = llama_get_logits_ith(bctx->ctx, batch.n_tokens - 1);
        int n_vocab = llama_n_vocab(bctx->model);

        std::vector<llama_token_data> candidates;
        candidates.reserve(n_vocab);
        for (llama_token token_id = 0; token_id < n_vocab; token_id++) {
            candidates.push_back({token_id, logits[token_id], 0.0f});
        }

        llama_token_data_array candidates_p = { candidates.data(), candidates.size(), false };

        llama_sample_top_p(bctx->ctx, &candidates_p, top_p, 1);
        llama_sample_temp(bctx->ctx, &candidates_p, temp);
        const llama_token new_token_id = llama_sample_token(bctx->ctx, &candidates_p);

        if (new_token_id == llama_token_eos(bctx->model)) break;

        jboolean should_continue = env->CallBooleanMethod(callback, onTokenMethod, (jint)new_token_id);
        if (!should_continue) break;

        batch.n_tokens = 0;
        batch.token[batch.n_tokens] = new_token_id;
        batch.pos[batch.n_tokens] = n_cur;
        batch.n_seq_id[batch.n_tokens] = 1;
        batch.seq_id[batch.n_tokens][0] = 0;
        batch.logits[batch.n_tokens] = true;
        batch.n_tokens++;

        if (llama_decode(bctx->ctx, batch) != 0) {
            LOGE("llama_decode failed during generation");
            break;
        }

        n_cur++;
        n_gen++;
    }

    llama_batch_free(batch);
}

JNIEXPORT jstring JNICALL
Java_com_aga_tinol_BonsaiNative_tokenToString(JNIEnv *env, jclass clazz, jlong handle, jint token_id) {
    BonsaiContext * bctx = reinterpret_cast<BonsaiContext *>(handle);
    std::vector<char> result(128);
    int n = llama_token_to_piece(bctx->model, (llama_token)token_id, result.data(), result.size());
    if (n < 0) {
        result.resize(-n);
        n = llama_token_to_piece(bctx->model, (llama_token)token_id, result.data(), result.size());
    }
    result.resize(n);
    return env->NewStringUTF(std::string(result.begin(), result.end()).c_str());
}

}
