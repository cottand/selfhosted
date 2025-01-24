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

var deployCommand = &cobra.Command{
	Use:           "deploy job.nix",
	Short:         "Queue a .nix Nomad job",
	RunE:          RunDeploy,
	Args:          cobra.MinimumNArgs(1),
	SilenceErrors: true,
	SilenceUsage:  true,
}
var versionFlag string
var useMasterFlag bool
var doDryRunFlag bool

func init() {
	deployCommand.Flags().StringVarP(&versionFlag, "version", "v", "", "version to pass to job")
	deployCommand.Flags().BoolVarP(&useMasterFlag, "master", "", false, "use current commit for versin")
	deployCommand.Flags().BoolVarP(&doDryRunFlag, "dry-run", "", false, "whether to print a job diff instead of deploying")
}

func RunDeploy(cmd *cobra.Command, args []string) error {
	jobFile := path.Clean(args[0])
	if useMasterFlag && versionFlag != "" {
		return errors.New("cannot use both -v and --master")
	}
	version := versionFlag
	if useMasterFlag {
		versionBytes, err := exec.Command("git", "rev-parse", "--short", "HEAD").Output()
		if err != nil {
			return fmt.Errorf("could not determine current revision: %v", err)
		}
		version = string(bytes.TrimSpace(versionBytes))
	}

	// check if file exists:
	stat, err := os.Stat(jobFile)
	if errors.Is(err, os.ErrNotExist) {
		return err
	}

	// resolve to a directory with job.nix by default
	if stat.IsDir() {
		jobFile = path.Join(jobFile, "job.nix")
		if _, err = os.Stat(jobFile); errors.Is(err, os.ErrNotExist) {
			return err
		}
	}

	if doDryRunFlag {
		cmd.Printf("Dry-run deploying %s", jobFile)
	} else {
		cmd.Printf("Deploying %s", jobFile)
	}
	if version != "" {
		cmd.Printf(" @ %s", version)
	}
	cmd.Println("...\n")

	pwd := os.Getenv("PWD")
	importedFile := `import ./` + jobFile

	cmd.Printf("Evaluating job... ")
	json := ""
	val, err := nix.Eval(importedFile, pwd, "daemon")
	if err != nil {
		return err
	}

	if val.Type() == gonix.NixTypeFunction && version == "" {
		importedWithParams := fmt.Sprintf(`(import ./%s ) { }`, jobFile)
		json, err = nix.EvalJson(importedWithParams, pwd, "daemon")
	}
	if val.Type() == gonix.NixTypeFunction && version != "" {
		importedWithParams := fmt.Sprintf(`(import ./%s ) { version = "%s"; }`, jobFile, version)
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

	var nomadRun *exec.Cmd
	if doDryRunFlag {
		nomadRun = exec.Command("nomad", "plan", "-json", "-")
	} else {
		nomadRun = exec.Command("nomad", "run", "-json", "-")
	}

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
