package tests;

import app.App;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

final class AppTest {
    @Test
    void canGetDefaultName() {
        assertThat( App.getName() ).isEqualTo( "Mary" );
    }

    @Test
    void canGetNameFromArgs() {
        assertThat( App.getName( "me" ) ).isEqualTo( "me" );
    }
}
