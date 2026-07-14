package com.aga.tinol

import android.content.Context
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

class SettingsActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)
        title = getString(R.string.settings)

        val prefs = getSharedPreferences("settings", Context.MODE_PRIVATE)
        val editTemp = findViewById<EditText>(R.id.edit_temp)
        val editTopP = findViewById<EditText>(R.id.edit_top_p)
        val editContext = findViewById<EditText>(R.id.edit_context)
        val editBatch = findViewById<EditText>(R.id.edit_batch)
        val btnSave = findViewById<Button>(R.id.btn_save)

        editTemp.setText(prefs.getFloat("temp", 0.8f).toString())
        editTopP.setText(prefs.getFloat("top_p", 0.95f).toString())
        editContext.setText(prefs.getInt("context_size", 2048).toString())
        editBatch.setText(prefs.getInt("batch_size", 256).toString())

        btnSave.setOnClickListener {
            try {
                prefs.edit()
                    .putFloat("temp", editTemp.text.toString().toFloat())
                    .putFloat("top_p", editTopP.text.toString().toFloat())
                    .putInt("context_size", editContext.text.toString().toInt())
                    .putInt("batch_size", editBatch.text.toString().toInt())
                    .apply()
                Toast.makeText(this, "Settings saved", Toast.LENGTH_SHORT).show()
                finish()
            } catch (e: Exception) {
                Toast.makeText(this, "Invalid input", Toast.LENGTH_SHORT).show()
            }
        }
    }
}
