package jb.example.error_prone;

/**
 * This is a main class.
 **/
public final class Main {
    // intentionally not final to trigger error-prone warning
    static String HELLO = "Hello ErrorProne";

    public static void main( String[] args ) {
        System.out.println( HELLO );
    }
}
