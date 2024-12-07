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
	Use:           "shipper [subcommand]",
	Short:         "shipper - all-in-one CLI for the homelab",
	Args:          cobra.MinimumNArgs(1),
	SilenceErrors: true,
	SilenceUsage:  true,
}

func init() {
	rootCmd.AddCommand(deployCommand)
}
