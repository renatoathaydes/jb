package app;

import hello.*;

public final class App {
    public static String getName( String... args ) {
        if ( args.length == 0 ) return "Mary";
        return args[ 0 ];
    }

    public static void main( String[] args ) {
        System.out.println( Greeting.to( getName( args ) ) );
    }
}