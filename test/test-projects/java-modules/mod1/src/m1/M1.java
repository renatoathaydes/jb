package m1;
import org.slf4j.*;

public class M1 {
    private static final Logger log = LoggerFactory.getLogger(M1.class);

    private final String value;

    public M1( String value ) {
        this.value = value;
        log.debug("Created M1 with value: {}", value);
    }

    public String getValue() {
        return value;
    }

    public String toString() {
        return "M1{value=" + value + "}";
    }
}
