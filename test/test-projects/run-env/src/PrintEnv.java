public final class PrintEnv {
    private static final String ENV_NAME = "MY_VAR";

    public static void main(String[] args) {
        System.out.println("MY_VAR is '" + System.getenv("MY_VAR") + "'");
    }
}