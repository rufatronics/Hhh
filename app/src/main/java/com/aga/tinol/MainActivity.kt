package com.aga.tinol

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import java.io.File
import java.io.FileOutputStream

class MainActivity : AppCompatActivity() {
    private lateinit var chatAdapter: ChatAdapter
    private var modelCtx: Long = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val recyclerView = findViewById<RecyclerView>(R.id.chat_recycler)
        chatAdapter = ChatAdapter()
        recyclerView.adapter = chatAdapter
        recyclerView.layoutManager = LinearLayoutManager(this)

        val messageInput = findViewById<EditText>(R.id.message_input)
        val sendButton = findViewById<Button>(R.id.send_button)

        sendButton.setOnClickListener {
            val text = messageInput.text.toString()
            if (text.isNotBlank()) {
                chatAdapter.addMessage(ChatMessage(text, true))
                messageInput.text.clear()
                generateResponse(text)
            }
        }

        // Load model in background
        Thread {
            try {
                val modelFile = prepareModelFile()
                modelCtx = BonsaiNative.loadModel(modelFile.absolutePath, 4)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }

    private fun prepareModelFile(): File {
        val file = File(filesDir, "Bonsai-1.7B-Q1_0.gguf")
        if (!file.exists()) {
            assets.open("models/Bonsai-1.7B-Q1_0.gguf").use { input ->
                FileOutputStream(file).use { output ->
                    input.copyTo(output)
                }
            }
        }
        return file
    }

    private fun generateResponse(prompt: String) {
        Thread {
            if (modelCtx == 0L) return@Thread

            val tokens = BonsaiNative.tokenize(modelCtx, prompt, true)
            val responseBuilder = StringBuilder()

            runOnUiThread {
                chatAdapter.addMessage(ChatMessage("", false))
            }

            BonsaiNative.generate(modelCtx, tokens, 100, 0.95f, 0.8f, object : TokenCallback {
                override fun onToken(tokenId: Int): Boolean {
                    val word = BonsaiNative.tokenToString(modelCtx, tokenId)
                    responseBuilder.append(word)
                    runOnUiThread {
                        chatAdapter.updateLastMessage(responseBuilder.toString())
                    }
                    return true
                }
            })
        }.start()
    }

    override fun onDestroy() {
        super.onDestroy()
        if (modelCtx != 0L) {
            BonsaiNative.freeModel(modelCtx)
        }
    }
}

data class ChatMessage(var text: String, val isUser: Boolean)

class ChatAdapter : RecyclerView.Adapter<ChatViewHolder>() {
    private val messages = mutableListOf<ChatMessage>()

    fun addMessage(message: ChatMessage) {
        messages.add(message)
        notifyItemInserted(messages.size - 1)
    }

    fun updateLastMessage(text: String) {
        if (messages.isNotEmpty()) {
            messages.last().text = text
            notifyItemChanged(messages.size - 1)
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ChatViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(android.R.layout.simple_list_item_1, parent, false)
        return ChatViewHolder(view)
    }

    override fun onBindViewHolder(holder: ChatViewHolder, position: Int) {
        val message = messages[position]
        (holder.itemView as TextView).text =
            (if (message.isUser) "You: " else "Bonsai: ") + message.text
    }

    override fun getItemCount() = messages.size
}

class ChatViewHolder(view: View) : RecyclerView.ViewHolder(view)
