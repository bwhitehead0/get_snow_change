# get_snow_change GitHub Action

This Action makes use of the ServiceNow API to retrieve details about a CHG ticket. Outputs can be used to validate a ticket state, etc.

## GitHub Action Use

To use this action in your workflow, invoke like the following:

```yaml
name: Get New ServiceNow CHG

on:
  push:
    tags:
    - '*'

jobs:
  encode:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v2

      - name: Get CHG Ticket
        id: change_detail
        uses: bwhitehead0/get_snow_change@main
        with:
          snow_url: "https://my_company.service-now.com"
          snow_user: "myUser"
          snow_password: ${{ secrets.mySnowPass }}
          snow_client_id: ${{ secrets.mySnowClientId }}
          snow_client_secret: ${{ secrets.mySnowClientSecret }}
          change_ticket_number: "CHG0012345"
          snow_timeout: "60"
          debug: "false"
        - name: Display CHG details
          run: |
            echo "CHG sys_id: ${{ steps.change_detail.outputs.change_sys_id }}"
            echo "CHG type: ${{ steps.change_detail.outputs.change_type }}"
            echo "CHG requested by: ${{ steps.change_detail.outputs.change_requested_by }}"
            echo "CHG CAB review: ${{ steps.change_detail.outputs.change_cab_reviewed }}"
            echo "CHG state: ${{ steps.change_detail.outputs.change_state }}"
            echo "CHG state code: ${{ steps.change_detail.outputs.change_state_code }}"
            echo "CHG start date: ${{ steps.change_detail.outputs.change_start_date }}"
            echo "CHG end date: ${{ steps.change_detail.outputs.change_end_date }}"
            echo "CHG cmdb_ci: ${{ steps.change_detail.outputs.change_cmdb_ci }}"
            echo "CHG cmdb_ci sys_id: ${{ steps.change_detail.outputs.change_cmdb_ci_sys_id }}"
            echo "CHG Detail: ${{ steps.change_detail.outputs.change_detail }}"
            
```

### Inputs

* `snow_url`: ServiceNow URL (e.g., https://my-company.service-now.com). **Required**.
* `snow_user`: ServiceNow username (Username + password or token are required). **Required**.
* `snow_password`: ServiceNow password (Username + password or token are required). **Required**.
* `snow_client_id`: ServiceNow Client ID for oAuth Token auth. **Optional** (Requires: User + pass + client ID + client secret).
* `snow_client_secret`: ServiceNow Client Secret for oAuth Token auth. **Optional** (Requires: User + pass + client ID + client secret).
* `debug`: Enable debug output. **Optional**, default='false'.
* `snow_timeout`: Timeout for ServiceNow API call. **Optional**, default='60'
* `change_ticket_number`: ServiceNow change ticket number. **Required**.

### Outputs

* `change_detail`: The full JSON response from the ServiceNow API
* `change_sys_id`: The sys_id of the change ticket
* `change_type`: The type of the change ticket
* `change_requested_by`: The user who requested the change ticket
* `change_cab_reviewed`: The CAB review status of the change ticket
* `change_state`: The state of the change ticket
* `change_state_code`: The state code of the change ticket
* `change_start_date`: The start date of the change ticket
* `change_end_date`: The end date of the change ticket
* `change_cmdb_ci`: The CMDB CI of the change ticket
* `change_cmdb_ci_sys_id`: The CMDB CI sys_id of the change ticket
