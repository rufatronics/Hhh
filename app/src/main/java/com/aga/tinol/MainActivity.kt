package com.aga.tinol

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ProgressBar
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
    private lateinit var downloadLayout: LinearLayout
    private lateinit var downloadStatus: TextView
    private lateinit var downloadProgress: ProgressBar
    private lateinit var btnDownload: Button
    private var modelCtx: Long = 0

    private val MODEL_URL = "https://huggingface.co/prism-ml/Bonsai-1.7B-gguf/resolve/main/Bonsai-1.7B-Q1_0.gguf"
    private val MODEL_NAME = "Bonsai-1.7B-Q1_0.gguf"

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
        downloadLayout = findViewById(R.id.download_layout)
        downloadStatus = findViewById(R.id.download_status)
        downloadProgress = findViewById(R.id.download_progress)
        btnDownload = findViewById(R.id.btn_download)

        btnDownload.setOnClickListener {
            startModelDownload()
        }

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
        when (item.itemId) {
            R.id.action_settings -> {
                startActivity(Intent(this, SettingsActivity::class.java))
                return true
            }
            R.id.action_help -> {
                startActivity(Intent(this, HelpActivity::class.java))
                return true
            }
        }
        return super.onOptionsItemSelected(item)
    }

    private fun loadModel() {
        val modelFile = File(filesDir, MODEL_NAME)
        if (!modelFile.exists()) {
            // Check if model exists in assets (baked-in case)
            try {
                assets.open("models/$MODEL_NAME").use { input ->
                    runOnUiThread { 
                        thinkingIndicator.text = "Extracting model..."
                        thinkingIndicator.visibility = View.VISIBLE 
                    }
                    FileOutputStream(modelFile).use { output ->
                        input.copyTo(output)
                    }
                }
            } catch (e: Exception) {
                // Not in assets, need to download
                runOnUiThread { downloadLayout.visibility = View.VISIBLE }
                return
            }
        }

        runOnUiThread { 
            thinkingIndicator.text = "Loading model..."
            thinkingIndicator.visibility = View.VISIBLE 
            downloadLayout.visibility = View.GONE
        }
        
        Thread {
            try {
                val prefs = getSharedPreferences("settings", Context.MODE_PRIVATE)
                val nCtx = prefs.getInt("context_size", 512)
                val nBatch = prefs.getInt("batch_size", 256)

                modelCtx = BonsaiNative.loadModel(modelFile.absolutePath, 4, nCtx, nBatch)
                
                runOnUiThread {
                    thinkingIndicator.visibility = View.GONE
                    thinkingIndicator.text = getString(R.string.thinking)
                    if (modelCtx == 0L) {
                        android.widget.Toast.makeText(this, "Failed to load model", android.widget.Toast.LENGTH_LONG).show()
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
                runOnUiThread { 
                    thinkingIndicator.visibility = View.GONE
                    android.widget.Toast.makeText(this, "Error: ${e.message}", android.widget.Toast.LENGTH_LONG).show()
                }
            }
        }.start()
    }

    private fun startModelDownload() {
        btnDownload.visibility = View.GONE
        downloadProgress.visibility = View.VISIBLE
        downloadStatus.text = "Starting download..."
        
        Thread {
            try {
                val url = java.net.URL(MODEL_URL)
                val connection = url.openConnection() as java.net.HttpURLConnection
                connection.connect()
                
                if (connection.responseCode != java.net.HttpURLConnection.HTTP_OK) {
                    throw Exception("Server returned HTTP ${connection.responseCode}")
                }
                
                val fileLength = connection.contentLength
                val input = java.io.BufferedInputStream(url.openStream())
                val output = FileOutputStream(File(filesDir, MODEL_NAME))
                
                val data = ByteArray(1024 * 8)
                var total: Long = 0
                var count: Int
                while (input.read(data).also { count = it } != -1) {
                    total += count.toLong()
                    if (fileLength > 0) {
                        val progress = (total * 100 / fileLength).toInt()
                        runOnUiThread {
                            downloadProgress.progress = progress
                            downloadStatus.text = getString(R.string.downloading_model, progress)
                        }
                    }
                    output.write(data, 0, count)
                }
                
                output.flush()
                output.close()
                input.close()
                
                runOnUiThread {
                    loadModel()
                }
            } catch (e: Exception) {
                e.printStackTrace()
                runOnUiThread {
                    btnDownload.visibility = View.VISIBLE
                    downloadProgress.visibility = View.GONE
                    downloadStatus.text = getString(R.string.download_failed)
                }
            }
        }.start()
    }

    private fun generateResponse(userPrompt: String) {
        Thread {
            if (modelCtx == 0L) return@Thread

            runOnUiThread { thinkingIndicator.visibility = View.VISIBLE }

            val prefs = getSharedPreferences("settings", Context.MODE_PRIVATE)
            val systemPrompt = prefs.getString("system_prompt", "You are a helpful AI assistant.") ?: ""
            val temp = prefs.getFloat("temp", 0.8f)
            val topP = prefs.getFloat("top_p", 0.95f)
            val topK = prefs.getInt("top_k", 40)
            
            // Simple chat format: System Prompt + User Prompt
            val fullPrompt = if (systemPrompt.isNotBlank()) {
                "$systemPrompt\n\nUser: $userPrompt\nAssistant:"
            } else {
                "User: $userPrompt\nAssistant:"
            }

            val tokens = BonsaiNative.tokenize(modelCtx, fullPrompt, true)
            val responseBuilder = StringBuilder()

            runOnUiThread {
                chatAdapter.addMessage(ChatMessage("", false))
            }

            BonsaiNative.generate(modelCtx, tokens, 512, topP, temp, topK, object : TokenCallback {
                override fun onToken(tokenId: Int): Boolean {
                    val word = BonsaiNative.tokenToString(modelCtx, tokenId)
                    responseBuilder.append(word)
                    runOnUiThread {
                        chatAdapter.updateLastMessage(responseBuilder.toString())
                    }
                    return true
                }
            })
            runOnUiThread { thinkingIndicator.visibility = View.GONE }
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
