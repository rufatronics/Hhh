package com.aga.tinol

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.Toolbar
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.button.MaterialButton
import java.io.File
import java.io.FileOutputStream

class MainActivity : AppCompatActivity() {
    lateinit var chatAdapter: ChatAdapter
    private lateinit var thinkingIndicator: TextView
    private var modelCtx: Long = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val toolbar = findViewById<Toolbar>(R.id.toolbar)
        setSupportActionBar(toolbar)
        toolbar.setOnMenuItemClickListener {
            if (it.itemId == R.id.action_settings) {
                startActivity(Intent(this, SettingsActivity::class.java))
                true
            } else false
        }

        val recyclerView = findViewById<RecyclerView>(R.id.chat_recycler)
        chatAdapter = ChatAdapter()
        recyclerView.adapter = chatAdapter
        recyclerView.layoutManager = LinearLayoutManager(this)

        thinkingIndicator = findViewById(R.id.thinking_indicator)
        val messageInput = findViewById<EditText>(R.id.message_input)
        val sendButton = findViewById<MaterialButton>(R.id.send_button)

        sendButton.setOnClickListener {
            val text = messageInput.text.toString()
            if (text.isNotBlank()) {
                chatAdapter.addMessage(ChatMessage(text, true))
                messageInput.text.clear()
                generateResponse(text)
            }
        }

        loadModel()
    }

    override fun onCreateOptionsMenu(menu: android.view.Menu?): Boolean {
        menuInflater.inflate(R.menu.main_menu, menu)
        return true
    }

    override fun onOptionsItemSelected(item: android.view.MenuItem): Boolean {
        if (item.itemId == R.id.action_settings) {
            startActivity(Intent(this, SettingsActivity::class.java))
            return true
        }
        return super.onOptionsItemSelected(item)
    }

    private fun loadModel() {
        Thread {
            try {
                val prefs = getSharedPreferences("settings", Context.MODE_PRIVATE)
                val nCtx = prefs.getInt("context_size", 2048)
                val nBatch = prefs.getInt("batch_size", 256)

                val modelFile = prepareModelFile()
                modelCtx = BonsaiNative.loadModel(modelFile.absolutePath, 4, nCtx, nBatch)
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

            runOnUiThread { thinkingIndicator.visibility = View.VISIBLE }

            val tokens = BonsaiNative.tokenize(modelCtx, prompt, true)
            val responseBuilder = StringBuilder()

            runOnUiThread {
                chatAdapter.addMessage(ChatMessage("", false))
            }

            val prefs = getSharedPreferences("settings", Context.MODE_PRIVATE)
            val temp = prefs.getFloat("temp", 0.8f)
            val topP = prefs.getFloat("top_p", 0.95f)

            BonsaiNative.generate(modelCtx, tokens, 512, topP, temp, object : TokenCallback {
                override fun onToken(tokenId: Int): Boolean {
                    val word = BonsaiNative.tokenToString(modelCtx, tokenId)
                    responseBuilder.append(word)
                    runOnUiThread {
                        thinkingIndicator.visibility = View.GONE
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

class ChatAdapter : RecyclerView.Adapter<RecyclerView.ViewHolder>() {
    val messages = mutableListOf<ChatMessage>()

    companion object {
        private const val TYPE_USER = 1
        private const val TYPE_BOT = 2
    }

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

    override fun getItemViewType(position: Int): Int {
        return if (messages[position].isUser) TYPE_USER else TYPE_BOT
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
        val layout = if (viewType == TYPE_USER) R.layout.item_message_user else R.layout.item_message_bot
        val view = LayoutInflater.from(parent.context).inflate(layout, parent, false)
        return MessageViewHolder(view)
    }

    override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
        (holder as MessageViewHolder).bind(messages[position])
    }

    override fun getItemCount() = messages.size

    class MessageViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        private val text: TextView = view.findViewById(R.id.message_text)
        fun bind(message: ChatMessage) {
            text.text = message.text
        }
    }
}
