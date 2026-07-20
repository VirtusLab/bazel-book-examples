package app;

import java.io.BufferedReader;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import java.util.Optional;

public final class MaintainerApp {
    private MaintainerApp() {}

    public static void main(String[] args) throws IOException {
        String mode = args.length > 0 ? args[0] : "dev";
        String policy = args.length > 1 ? readPolicy(args[1]) : "policy=not-provided";

        System.out.println(render(mode, policy));
    }

    static String render(String mode) {
        return render(mode, "policy=not-read");
    }

    static String render(String mode, String policy) {
        return String.join(
                System.lineSeparator(),
                "launcher=java",
                "mode=" + mode,
                "platform=" + PlatformProfile.name(),
                "message=" + PlatformProfile.message(),
                "policy=" + normalizePolicy(policy));
    }

    private static String readPolicy(String runfilesPath) throws IOException {
        Optional<Path> resolved = resolveRunfile(runfilesPath);
        if (resolved.isEmpty()) {
            throw new IOException("runfile not found: " + runfilesPath);
        }
        return Files.readString(resolved.get());
    }

    private static Optional<Path> resolveRunfile(String runfilesPath) throws IOException {
        Map<String, String> env = System.getenv();

        String runfilesDir = env.get("RUNFILES_DIR");
        if (runfilesDir != null && !runfilesDir.isEmpty()) {
            Path path = Path.of(runfilesDir, runfilesPath);
            if (Files.exists(path)) {
                return Optional.of(path);
            }
        }

        String manifest = env.get("RUNFILES_MANIFEST_FILE");
        if (manifest != null && !manifest.isEmpty()) {
            return resolveFromManifest(Path.of(manifest), runfilesPath);
        }

        Path path = Path.of(runfilesPath);
        if (Files.exists(path)) {
            return Optional.of(path);
        }

        return Optional.empty();
    }

    private static Optional<Path> resolveFromManifest(Path manifest, String runfilesPath) throws IOException {
        try (BufferedReader reader = Files.newBufferedReader(manifest)) {
            String line;
            while ((line = reader.readLine()) != null) {
                if (line.equals(runfilesPath)) {
                    return Optional.of(Path.of(runfilesPath));
                }
                String prefix = runfilesPath + " ";
                if (line.startsWith(prefix)) {
                    return Optional.of(Path.of(line.substring(prefix.length())));
                }
            }
        }
        return Optional.empty();
    }

    static String normalizePolicy(String policy) {
        return policy.replace(System.lineSeparator(), " ").trim();
    }
}
