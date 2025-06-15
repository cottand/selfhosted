package util

import "strings"

func KebabToSnakeCase(name string) string {
	return strings.ReplaceAll(name, "-", "_")
}

func SnakeToKebabCase(name string) string  {
	return strings.ReplaceAll(name, "_", "-")
}
