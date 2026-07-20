package app;

public final class Calculator {
    private Calculator() {}

    public static String classify(int value) {
        if (value < 0) {
            return "negative";
        }
        if (value == 0) {
            return "zero";
        }
        return "positive";
    }
}
