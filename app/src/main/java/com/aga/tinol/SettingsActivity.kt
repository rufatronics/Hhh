package com.aga.tinol

import android.app.ActivityManager
import android.content.Context
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

class SettingsActivity : AppCompatActivity() {
    
    private var isPowerfulDevice = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)
        
        detectDeviceCapability()
        setupUI()
    }

    private fun detectDeviceCapability() {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)
        
        val totalRamGb = memoryInfo.totalMem / (1024 * 1024 * 1024.0)
        val is64Bit = Build.SUPPORTED_ABIS.any { it.contains("64") }
        
        // A device is "powerful" if it has 64-bit arch and > 4GB RAM
        isPowerfulDevice = is64Bit && totalRamGb > 4.0
    }

    private fun setupUI() {
        val prefs = getSharedPreferences("settings", Context.MODE_PRIVATE)
        
        val tvStatus = findViewById<TextView>(R.id.tv_device_status)
        val tvWarning = findViewById<TextView>(R.id.tv_device_warning)
        val layoutStatus = findViewById<LinearLayout>(R.id.layout_device_status)
        
        val editSystemPrompt = findViewById<EditText>(R.id.edit_system_prompt)
        val editTemp = findViewById<EditText>(R.id.edit_temp)
        val editTopP = findViewById<EditText>(R.id.edit_top_p)
        val editTopK = findViewById<EditText>(R.id.edit_top_k)
        val editContext = findViewById<EditText>(R.id.edit_context)
        val btnSave = findViewById<Button>(R.id.btn_save)

        // Update Status UI
        if (isPowerfulDevice) {
            tvStatus.text = getString(R.string.device_powerful)
            layoutStatus.setBackgroundResource(R.drawable.bg_card_limited) // Green
        } else {
            tvStatus.text = getString(R.string.device_limited)
            tvWarning.visibility = View.VISIBLE
            layoutStatus.setBackgroundColor(Color.parseColor("#E53935")) // Red
            
            // Lock critical settings for weak devices
            editContext.isEnabled = false
            editContext.alpha = 0.5f
        }

        // Load current values
        editSystemPrompt.setText(prefs.getString("system_prompt", "You are a helpful AI assistant."))
        editTemp.setText(prefs.getFloat("temp", 0.8f).toString())
        editTopP.setText(prefs.getFloat("top_p", 0.95f).toString())
        editTopK.setText(prefs.getInt("top_k", 40).toString())
        editContext.setText(prefs.getInt("context_size", if (isPowerfulDevice) 2048 else 512).toString())

        btnSave.setOnClickListener {
            try {
                val temp = editTemp.text.toString().toFloat()
                val topP = editTopP.text.toString().toFloat()
                val topK = editTopK.text.toString().toInt()
                val contextSize = editContext.text.toString().toInt()
                val systemPrompt = editSystemPrompt.text.toString()

                if (temp !in 0.1f..2.0f || topP !in 0.0f..1.0f || topK !in 1..100) {
                    Toast.makeText(this, "Values out of range", Toast.LENGTH_SHORT).show()
                    return@setOnClickListener
                }

                prefs.edit()
                    .putString("system_prompt", systemPrompt)
                    .putFloat("temp", temp)
                    .putFloat("top_p", topP)
                    .putInt("top_k", topK)
                    .putInt("context_size", contextSize)
                    .apply()
                
                Toast.makeText(this, "Settings saved", Toast.LENGTH_SHORT).show()
                finish()
            } catch (e: Exception) {
                Toast.makeText(this, "Invalid input format", Toast.LENGTH_SHORT).show()
            }
        }
    }
}
