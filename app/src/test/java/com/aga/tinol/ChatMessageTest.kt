package com.aga.tinol

import org.junit.Assert.assertEquals
import org.junit.Test

class ChatMessageTest {
    @Test
    fun testChatMessage() {
        val message = ChatMessage("Hello", true)
        assertEquals("Hello", message.text)
        assertEquals(true, message.isUser)
    }
}
