package com.aga.tinol

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

    @Test
    fun testAppLaunchAndSend() {
        // Wait for model initialization
        Thread.sleep(3000)

        // Type a simple greeting
        onView(withId(R.id.message_input))
            .perform(typeText("Hi"), closeSoftKeyboard())

        // Click send button
        onView(withId(R.id.send_button))
            .perform(click())

        // Allow some time for token generation
        Thread.sleep(5000)

        // Confirm we can find the adapter messages list
        onView(withId(R.id.chat_recycler))
            .check(matches(isDisplayed()))
    }
}
