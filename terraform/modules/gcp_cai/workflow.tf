resource "google_workflows_workflow" "gcp_cai" {
  project     = var.project_id
  name        = "${var.module_name}-${var.target_type}s-${var.target_id}"
  region      = var.location
  description = "GCP Workflow for ${var.module_name}/${var.target_type}s/${var.target_id}"

  labels          = var.labels
  service_account = google_service_account.cai_sa.email
  call_log_level  = var.workflow_call_log_level
  source_contents = <<EOF
main:
    params: [args]
    steps:
    - init:
        assign:
          - target_type: $${args.target_type +"s"}
          - target_id: $${args.target_id}            
          - output_bucket: $${args.output_bucket}
          - output_prefix: $${args.output_prefix}
          - content_type: $${args.content_type}
          - export_prefix: $${args.output_prefix +"/"+ args.target_type +"s/"+ args.target_id +"/"+ args.content_type}
          - retry_count: 0
          - max_retries: $${args.max_retries}
          - sleep: $${args.sleep_seconds}
    - export_assets:
        try:
            call: execute_export
            args:
                target_type: "$${target_type}"
                target_id: "$${target_id}"
                output_bucket: "$${output_bucket}"
                export_prefix: "$${export_prefix}"
                content_type: "$${content_type}"
            result: export_result
        except:
            as: e
            steps:
            - retry_export:
                call: execute_export
                args:
                    target_type: "$${target_type}"
                    target_id: "$${target_id}"
                    output_bucket: "$${output_bucket}"
                    export_prefix: "$${export_prefix}"
                    content_type: "$${content_type}"
                result: export_result
    - wait_for_operation_status:
        call: sys.sleep
        args:
          seconds: $${sleep}
    - get_operation:
        call: http.get
        args:
            url: $${"https://cloudasset.googleapis.com/v1/" + map.get(export_result.body, "name")}
            auth:
                type: OAuth2
                scopes: "https://www.googleapis.com/auth/cloud-platform"
        result: operation_status
    - check_done:
        switch:
          - condition: $${default(map.get(operation_status.body, "done"), false) == true}
            next: finish_workflow
          - condition: $${retry_count >= max_retries}
            next: error
          - condition: true
            next: increment_retry
    - increment_retry:
        assign:
          - retry_count: $${retry_count + 1}
        next: wait_for_operation_status
    - error:
        raise: "Max retries reached and operation is not complete."
    - finish_workflow:
        return: $${operation_status.body.response.outputResult}

execute_export:
    params: [target_type, target_id, output_bucket, export_prefix, content_type]
    steps:
    - export_assets:
        call: http.post
        args:
            url: $${"https://cloudasset.googleapis.com/v1/"+ target_type +"/"+ target_id +":exportAssets"}
            auth:
                type: OAuth2
                scopes: "https://www.googleapis.com/auth/cloud-platform"
            body:
                outputConfig:
                    gcsDestination:
                        uri_prefix: $${"gs://"+ output_bucket +"/"+ export_prefix}
                contentType: "$${text.to_upper(content_type)}"
        result: export_result
    - return:
        return: $${export_result}
  EOF
}
