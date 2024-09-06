package main

import (
	"bytes"
	"errors"
	"fmt"
	"github.com/cottand/selfhosted/dev-go/lib/nix"
	"github.com/farcaller/gonix"
	"github.com/monzo/terrors"
	"github.com/spf13/cobra"
	"os"
	"os/exec"
	"path"
)

func RunCommand(cmd *cobra.Command, args []string) error {
	jobFile := path.Clean(args[0])
	cmd.Printf("Deploying %s", jobFile)
	if versionFlag != "" {
		cmd.Printf(" @ %s", versionFlag)
	}
	cmd.Println("...\n")

	// check if file exists:
	if _, err := os.Stat(jobFile); errors.Is(err, os.ErrNotExist) {
		return err
	}

	pwd := os.Getenv("PWD")
	importedFile := `import ./` + jobFile

	cmd.Printf("Evaluating job... ")
	json := ""
	val, err := nix.Eval(importedFile, pwd, "daemon")
	if err != nil {
		return err
	}

	if val.Type() == gonix.NixTypeFunction && versionFlag == "" {
		importedWithParams := fmt.Sprintf(`(import ./%s ) { }`, jobFile)
		json, err = nix.EvalJson(importedWithParams, pwd, "daemon")
	}
	if val.Type() == gonix.NixTypeFunction && versionFlag != "" {
		importedWithParams := fmt.Sprintf(`(import ./%s ) { version = "%s"; }`, jobFile, versionFlag)
		json, err = nix.EvalJson(importedWithParams, pwd, "daemon")
	} else if val.Type() == gonix.NixTypeAttrs {
		json, err = nix.EvalJson(importedFile, pwd, "daemon")
	} else {
		err = errors.New("unexpected type for job: expected a thunk or an attrSet")
	}

	if err != nil {
		return errors.New("failed to evaluate imported template JSON: " + err.Error())
	}

	cmd.Println("done.")
	if versionFlag != "" && val.Type() != gonix.NixTypeFunction {
		cmd.Println("warning: ignoring version flag as job does not take arguments")
	}
	b := bytes.NewBufferString(json)

	nomadRun := exec.Command("nomad", "run", "-json", "-")
	nomadRun.Stderr = os.Stderr
	nomadRun.Stdout = os.Stdout
	nomadRun.Stdin = b

	err = nomadRun.Start()
	if err := terrors.Augment(err, "failed to run nomad", nil); err != nil {
		return err
	}

	_ = nomadRun.Wait()

	return nil
}
