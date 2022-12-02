package jb.api;

/**
 * Exception representing a build error.
 */
public final class JbException extends RuntimeException {
    public JbException(String message) {
        super(message);
    }
}
