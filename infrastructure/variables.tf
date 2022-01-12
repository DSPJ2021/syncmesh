variable "project" {
  type    = string
  default = "dspj-315716"
}

variable "public_access" {
  type    = bool
  default = true
}

variable "machine_type" {
  type        = string
  default     = "f1-micro"
  description = "The Machine Type used for all VMs"
}

variable "seperator_request_ip" {
  type        = string
  default     = "92.60.39.199"
  description = "IP Address that is used to seperate different Scenarios in the Logs"
}

variable "instance_scenario" {
  type    = string
  default = "with-latency-3"
  validation {
    condition     = contains(["with-latency-3", "without-latency-3", "with-latency-6", "with-latency-9", "with-latency-12"], var.instance_scenario)
    error_message = "Allowed values for scenario are \"with-latency-3\", \"without-latency-3\", or \"with-latency-6\"."
  }
}

variable "scenario" {
  type    = string
  default = "baseline"
  validation {
    condition     = contains(["baseline", "syncmesh", "advanced-mongo", "distributed-gundb"], var.scenario)
    error_message = "Allowed values for scenario are \"syncmesh\", \"advanced-mongo\", \"distributed-gundb\" or \"baseline\"."
  }
}
variable "test_client_repetitions" {
  type    = number
  default = 20
}

variable "test_sleep_time" {
  type        = number
  default     = 120
  description = "Time Between each testrun (in seconds)"
}

variable "test_pre_time" {
  type        = number
  default     = 60
  description = "Time before the seperation request (in seconds)"
}

variable "test_mongo_version" {
  type        = string
  default     = "5.0.2"
  description = "Mongo Version"
}

variable "test_node_version" {
  type        = string
  default     = "14"
  description = "Node Version"
}

variable "test_gundb_version" {
  type        = string
  default     = "0.2020.1235"
  description = "GUNDB Version"
}


variable "ssh_keys" {
  type = list(object({
    keymaterial = string
    user        = string
  }))
  description = "list of public ssh keys that have access to the VMs"
  default = [
    {
      user        = "dnhb"
      keymaterial = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDSbM+h0IAyf0uY6NQgyHj80IDwyPsmRpuoOXT6mkEqG05xCBk28iXsqgofP+4RXQFjHSFmQf+9Jb+TtQfg938fq6Nok+G3/iTQJAP+YlC+1nomup5iBRBb7BDJqtDJJPxgFo6J8xx+Ivcuy9xEwenbsEX6NNCNCtCsG8301R26MdYePz0BjPO+krfojI1pVyLH2rN6NcDiUM9FwZV2SYFRiVxEvdbGt6kqcLZAISN0Gq761MU0nVMCbQYkmq78Rzo2hZMYShHmhsLqIlH3A0zyznp8huYBe6PX/Tg1Vwm6193YTPmqnNmC+ibMD87PbdzizLKz3lncUKDTF2H0+7xVr2SanDzfYNfKIEPVO8ud1QXvWzxcdXWyzCjhomEbKPMjQIg6Dlz59lukX/geb2XYDOs9XEYsri/rhfXyrUJY0w5fgse1/PEH+1V3mgr1KN5zpinudijEyGE02dcKS8me5RIx9TUPlk5BXRgDAWVmkbtJSncODfo5ha10DvZJtKk= dnhb"
    },
    {
      user        = "kreutz"
      keymaterial = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCuQjk7NgImB+0hIAKwTSHii5yoVzckN/oNYvrWl4sjvRIqAFDdz/UdCIm8euyoK8VEADQbJA+Jbz72AzDdpeB5lvd+A6xhfT58YBQ6vHAkiu3HMxvrJXOAKd4fXRRz0mmCCmKhoFW3HFWGLlaMn3SA1O7ayqSGErJzpbXsf8nhMD4eh4V8WlhakRML5ynCBkykHvuMYhmsZMDMDsyfTKj7Gsg2/95FwJu99u9Xb2bP2N0c/psNd9M/x6rfeQSadlqPziptw7q2Nl2DYTgjWS4hGtpQN8Yeexrnyz7rpb1Oo51mt0kRQyRvjckrIzYl6qJq/qqYf3+1NiRwqBANuLAbzd5UBMyGrZLIAujlURXkvXzkyLaeLx/TI8nS9/TC6XK6kZBivsfUyFDrF2RfXR9pH29YHEp05QPsQSEH7cIi6rvr5JQTjVgtReDy2u8VakrXWwK6ohCU0qCHEJNKbhlU4XKW5SBzbet+qN1PIUekBqZLvSNtA+/xGXChXGHLs4y5S3d/ru1n29nVTQYDxSH65IMCnPSfAnGk6V9Hp0sxIH5IVFpys+IyxvX35m0nkJWUim8oH/V/AjkPKY146P20Rr9m6eYduzdvbXdKXcZQywstqPAVOFRT/RerxaGfpmLKbzB7hjPdC2m3OigqbtZwsf5P3RZKTO+gF1Gp6R7Tfw== kreutz"
    },
    {
      user        = "dk"
      keymaterial = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCUKJ2o4RatYlUHYy7rK+VmYJd24Esq1NkjC/JQzUJhan4T/akLYtPeCsweGGdBii6E1aN3JDKUBCz1fTNbn+xWBaMggFt0pa/yU6RKvMpIx0LZUf98Z/jS1dzJKh5/0Ze2kcGEE7NYGoodFWf7ROjqD4/DJTHI7bAtnqbEUUiNkeX/6IGhgET7jCjS5f1NYC86o4xXBX7BXuFGlQRbRvKzb3a067zLpJasg/6AKacnMC6aITit6tLWaIXbo8XWqRjd3S77WmD4Odx/Vg05x9hoAMi88r4i+1cx1gfDx3EwLWNw+qa2DOvQfnFqBqzr3u3InedaFGA1ZKOyczWh2xmi7cfM2SLo4aPX9yaEyPfwlWHgNs/LGHg95x/p8FRTC1JgqgQDiB6DoACvR6jfV75kF5+apsg9qWTXQqMjPshJP1KP3tcudR9wCt7hAUIJZmDWbkugwgHyZQPqpP2O8Mk2GvVooOrs8MykhMOO3osNeEwRRgG1ny55LBFzugBUzx8= dk"
    }
  ]
}
