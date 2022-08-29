package lists;
import java.util.*;
public class ListFactory {
    public static List<Integer> listOf(Integer... integers) {
        return Arrays.asList(integers);
    }
}
