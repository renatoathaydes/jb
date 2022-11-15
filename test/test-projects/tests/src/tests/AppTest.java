package tests;

import app.App;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

final class AppTest {
    @Test
    @Tag( "t1" )
    void canGetDefaultName() {
        assertThat( App.getName() ).isEqualTo( "Mary" );
    }

    @Test
    void canGetNameFromArgs() {
        assertThat( App.getName( "me" ) ).isEqualTo( "me" );
    }
}
