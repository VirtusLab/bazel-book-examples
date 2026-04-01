package app;

public class LibTest {
    public static void main(String[] args) {
        if (!"hello".equals(Lib.greet())) {
            System.exit(1);
        }
    }
}
