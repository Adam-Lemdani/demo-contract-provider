package com.example.provider;

/**
 * Response body for GET /api/greetings/{name}.
 *
 * <p>The {@code message} field is the contract-relevant field. Renaming or
 * removing it is the canonical "breaking change" used in the demo, and must
 * cause the consumer verification to fail.
 */
public record Greeting(String message) {
}
