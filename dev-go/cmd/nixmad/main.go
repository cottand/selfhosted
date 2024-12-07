package main

import (
	"fmt"
	"github.com/spf13/cobra"
	"os"
)

func main() {
	err := rootCmd.Execute()
	if err != nil {
		_, _ = fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

var rootCmd = &cobra.Command{
	Use:           "nixmad ./path/to/job.nix",
	Short:         "nixmad is a tool for deploying Nix-templated Nomad jobs",
	RunE:          RunCommand,
	Args:          cobra.MinimumNArgs(1),
	SilenceErrors: true,
	SilenceUsage:  true,
}

var versionFlag string
var useMasterFlag bool

func init() {
	rootCmd.Flags().StringVarP(&versionFlag, "version", "v", "", "version to pass to job")
	rootCmd.Flags().BoolVarP(&useMasterFlag, "master", "", false, "use current commit for versin")
}
