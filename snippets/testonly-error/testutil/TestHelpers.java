package testutil;

public class TestHelpers {
    public static void assertOk(boolean condition) {
        if (!condition) throw new AssertionError("not ok");
    }
}
