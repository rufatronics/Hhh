package com.aga.tinol

import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.*
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MainActivityUITest {

    @get:Rule
    val activityRule = ActivityScenarioRule(MainActivity::class.java)

    private fun sendMessageAndAssertResponse(prompt: String, messageIndex: Int) {
        Log.i("TinolTestLog", "USER_PROMPT[$messageIndex]: $prompt")

        // Type the user prompt
        onView(withId(R.id.message_input))
            .perform(typeText(prompt), closeSoftKeyboard())

        // Click the send button
        onView(withId(R.id.send_button))
            .perform(click())

        // Wait for generation to start (thinking indicator becomes visible)
        Thread.sleep(1000)

        // Wait for generation to finish (thinking indicator becomes gone)
        var elapsed = 0
        val maxWait = 25000 // 25 seconds max wait for each token generation in tests
        while (elapsed < maxWait) {
            try {
                onView(withId(R.id.thinking_indicator))
                    .check(matches(withEffectiveVisibility(Visibility.GONE)))
                break
            } catch (e: AssertionError) {
                Thread.sleep(500)
                elapsed += 500
            }
        }

        // Add a brief cushion for rendering
        Thread.sleep(1000)

        // Verify the recycler view is displayed and contains our messages
        onView(withId(R.id.chat_recycler))
            .check(matches(isDisplayed()))

        // Read and log the generated response
        activityRule.scenario.onActivity { activity ->
            val adapter = activity.chatAdapter
            val messages = adapter.messages
            if (messages.size > 0) {
                val lastMsg = messages.last()
                Log.i("TinolTestLog", "BOT_RESPONSE[$messageIndex]: ${lastMsg.text}")
            }
        }
    }

    @Test
    fun testAppLaunchAndSendFiveMessages() {
        // Wait for model initialization
        Thread.sleep(5000)

        val prompts = listOf(
            "Hello, how are you?",
            "What is your name?",
            "Can you tell me a story?",
            "What is 2 plus 2?",
            "Goodbye!"
        )

        for ((index, prompt) in prompts.withIndex()) {
            sendMessageAndAssertResponse(prompt, index)
        }
    }
}
