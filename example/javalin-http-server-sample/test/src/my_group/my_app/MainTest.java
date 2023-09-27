package my_group.my_app;

import io.javalin.Javalin;
import io.javalin.testtools.JavalinTest;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

final class MainTest {

    Javalin app = new Main().javalin();

    @Test
    void GET() {
        JavalinTest.test( app, ( server, client ) -> {
            assertThat( client.get( "/" ).code() ).isEqualTo( 200 );
            assertThat( client.get( "/" ).body().string() ).isEqualTo( "Hello World" );
        } );
    }

}
