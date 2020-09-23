module "ssm" {
  source  = "hazelops/ssm-secrets/aws"
  version = "~> 1.0"

  env      = var.env
  app_name = var.name
  names    = local.secret_names
}

// TODO: Add ability to pass sidecar monitoring stuff here (defined globally somewhere else)
resource "aws_ecs_task_definition" "this" {
  family             = var.ecs_task_family_name != "" ? var.ecs_task_family_name : "${var.env}-${var.name}"
  execution_role_arn = aws_iam_role.this.arn
  // TODO: Create a separate task role
  task_role_arn = aws_iam_role.this.arn
  cpu           = var.cpu
  memory        = var.memory

  dynamic "volume" {
    for_each = var.volumes
    content {
      name      = volume.value.name
      host_path = lookup(volume.value, "host_path", null)

      dynamic "docker_volume_configuration" {
        for_each = lookup(volume.value, "docker_volume_configuration", [])
        content {
          scope         = lookup(docker_volume_configuration.value, "scope", null)
          autoprovision = lookup(docker_volume_configuration.value, "autoprovision", null)
          driver        = lookup(docker_volume_configuration.value, "driver", null)
          driver_opts   = lookup(docker_volume_configuration.value, "driver_opts", null)
          labels        = lookup(docker_volume_configuration.value, "labels", null)
        }
      }

      dynamic "efs_volume_configuration" {
        for_each = lookup(volume.value, "efs_volume_configuration", [])
        content {
          file_system_id          = lookup(efs_volume_configuration.value, "file_system_id", null)
          root_directory          = lookup(efs_volume_configuration.value, "root_directory", null)
          transit_encryption      = lookup(efs_volume_configuration.value, "transit_encryption", null)
          transit_encryption_port = lookup(efs_volume_configuration.value, "transit_encryption_port", null)

          dynamic "authorization_config" {
            for_each = length(lookup(efs_volume_configuration.value, "authorization_config", {})) == 0 ? [] : [
              lookup(efs_volume_configuration.value, "authorization_config", {})
            ]
            content {
              access_point_id = lookup(authorization_config.value, "access_point_id", null)
              iam             = lookup(authorization_config.value, "iam", null)
            }
          }
        }
      }
    }
  }
  network_mode             = var.ecs_network_mode
  requires_compatibilities = [var.ecs_launch_type]
  container_definitions    = jsonencode(local.container_definitions)

  //  dynamic "volume" {
  //    for_each = local.volumes
  //    content {
  //      name = volume.value["name"]
  ////      host_path = var.volume["mount_point"]
  //      dynamic "efs_volume_configuration" {
  //        for_each = local.volumes
  //        content {
  //          file_system_id          = efs_volume_configuration.value["file_system_id"]
  //          root_directory          = efs_volume_configuration.value["root_directory"]
  //          transit_encryption      = efs_volume_configuration.value["transit_encryption"]
  //          transit_encryption_port = efs_volume_configuration.value["transit_encryption_port"]
  //          //        authorization_config {
  //          //          access_point_id = aws_efs_access_point.test.id
  //          //          iam             = "ENABLED"
  //          //        }
  //        }
  //      }
  //      }
  //
  //
  //    }
  //
  //  volume {
  //    name = var.volume["name"]
  //    host_path = var.volume["mount_point"]
  //    efs_volume_configuration {
  //              file_system_id          = var.volume["file_system_id"]
  //              root_directory          = var.volume["root_directory"]
  //              transit_encryption      = var.volume["transit_encryption"]
  //              transit_encryption_port = var.volume["transit_encryption_port"]
  //
  //            }
  //  }
}

resource "aws_cloudwatch_log_group" "this" {
  name = "${var.env}-${var.name}"

  tags = {
    "Env"         = var.env
    "Environment" = var.env
    "Application" = "${var.env}-${var.name}"
  }
}
