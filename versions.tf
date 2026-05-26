terraform {
  required_version = ">= 1.5.7"

  required_providers {
    opentelekomcloud = {
      source  = "opentelekomcloud/opentelekomcloud"
      version = ">= 1.36.52, < 2.0.0"
    }
    errorcheck = {
      source  = "iits-consulting/errorcheck"
      version = "3.0.3"
    }
  }
}
