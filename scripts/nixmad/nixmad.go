package main

import (
	"fmt"
	"io"
	"os"
	"os/exec"
)

func main() {
	file := os.Args[2]
	var version string
	if len(os.Args) > 3 {
		version = os.Args[3]
		println(fmt.Printf("Deploying %s @ %s", file, version))
	} else {
		println(fmt.Printf("Deploying %s", file))
	}

	nixEval := exec.Command("nix",
		"eval",
		"-f", file,
		"--json",
		"--show-trace",
		"--apply", evalJobScript(version),
	)
	nixEval.Stderr = os.Stderr

	nomadRun := exec.Command("nomad", "run", "-json", "-")
	nomadRun.Stderr = os.Stderr
	nomadRun.Stdout = os.Stdout
	r, w := io.Pipe()
	defer r.Close()

	nixEval.Stdout = w
	nomadRun.Stdin = r

	_ = nixEval.Start()
	_ = nomadRun.Start()

	go func() {
		defer w.Close()

		_ = nixEval.Wait()
	}()

	_ = nomadRun.Wait()

}

var evalJobFilePath = "@applyOnJobNixPath@"

func evalJobScript(versionArg string) string {
	if versionArg == "" {
		return fmt.Sprintf(`job: (import "%s") { inherit job; }`, evalJobFilePath)
	}
	return fmt.Sprintf(`job: (import "%s") { inherit job; version = "%s"; }`, evalJobFilePath, versionArg)
}
