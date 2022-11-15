package my_group.my_app;

import io.javalin.Javalin;

public class Main {
    private final Javalin app;

    Main() {
        app = Javalin.create()
                .get( "/", ctx -> ctx.result( "Hello World" ) )
                .get( "/stop", ctx -> {
                    new Thread( () -> {
                        try {
                            Thread.sleep( 100 );
                        } catch ( Exception e ) {
                        }
                        System.exit( 0 );
                    } ).start();
                    ctx.result( "Hello World" );
                } );
    }

    public Javalin javalin() {
        return app;
    }

    public static void main( String[] args ) {
        new Main().app.start( 7070 );
    }
}