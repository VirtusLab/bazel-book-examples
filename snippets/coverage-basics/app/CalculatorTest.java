package app;

public class CalculatorTest {
    public static void main(String[] args) {
        assertEquals("zero", Calculator.classify(0));
        assertEquals("positive", Calculator.classify(7));
    }

    private static void assertEquals(String expected, String actual) {
        if (!expected.equals(actual)) {
            throw new AssertionError("expected " + expected + " but got " + actual);
        }
    }
}
