package com.example.provider;

/**
 * Request body for POST /api/greetings.
 */
public record GreetingRequest(String name) {
}
