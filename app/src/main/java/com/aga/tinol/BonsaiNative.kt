package com.aga.tinol

interface TokenCallback {
    fun onToken(tokenId: Int): Boolean
}

object BonsaiNative {
    init {
        System.loadLibrary("tinol")
    }

    external fun loadModel(modelPath: String, nThreads: Int): Long
    external fun freeModel(ctx: Long)
    external fun tokenize(ctx: Long, prompt: String, addBos: Boolean): IntArray
    external fun generate(
        ctx: Long,
        inputTokens: IntArray,
        maxTokens: Int,
        topP: Float,
        temp: Float,
        callback: TokenCallback
    )
    external fun tokenToString(ctx: Long, tokenId: Int): String
}
