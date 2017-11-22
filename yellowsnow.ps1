#!/usr/bin/powershell
## VARS

$aca_resource = ""
$contenttype= "application/json"
$header = @{Accept = "application/json"; Authorization = ""}
$serviceaccountuser = ""
$ac_vars_table = ""

####################

# Connection to ServiceNow
# Only collect Tickets Equal to Cat_Item, DC, SO

$aca_invoke = Invoke-RestMethod -Method Get -Uri $aca_resource -ContentType $contenttype -Headers $header

# Begin Breakouts/Parsing of Request, SO, DC, Description
$breakouts = $aca_invoke.result | select request, service_offering, u_data_center, description

# Parse Ticket Information
$tickets = $aca_invoke.result | select number, sys_id

for ($i=0; $i -lt $tickets.number.Count; $i++){
    $ticket = $tickets[$i]
    $ticket_number = $ticket.number
    $ticket_sys_id = $ticket.sys_id

    Write-Host $ticket_number
    Write-Host "=================="

    ## Building out Requested For > User Info + SO Info + DC Info
    ## RITM Information Build
    #  Request Invoke
    $temp1 = Invoke-RestMethod -Method Get -Uri $breakouts[$i].request.link -ContentType $contenttype -Headers $header

    #  Requested_for Link
    $userbreakout = $temp1.result | select requested_for

    #  Requested_for Invoke
    $temp2 = Invoke-RestMethod -Method Get -Uri $userbreakout[0].requested_for.link -ContentType $contenttype -Headers $header

    #  User Info Array
    $user_info = $temp2.result | select sys_id, user_name, first_name, last_name, email, mobile_phone
    $user = @{
      usys_id = $temp2.result.sys_id;
      sso = $user_info.user_name;
      first_name = $user_info.first_name;
      last_name = $user_info.last_name;
      email = $user_info.email;
      phone = $user_info.mobile_phone
    }
#    Write-Host $user


    ## Service Information Build
    #  Service Offering Invoke
    $temp3 = Invoke-RestMethod -Method Get -Uri $breakouts[$i].service_offering.link -ContentType $contenttype -Headers $header

    #  SO Info Array
    $so_info = $temp3.result | select sys_id, name
    $so = @{
      sosys_id = $so_info.sys_id;
      soname = $so_info.name
    }
#    Write-Host $so

    <#
    ## DC Information Build
    Write-Output $question[$x]" = "$answer[$x] | Select-String "AD Security Group ="


    #  DataCenter invoke
    $temp4 = Invoke-RestMethod -Method Get -Uri $breakouts[$i].u_data_center.link -ContentType $contenttype -Headers $header

    # DC Info Array
    $dc_info = $temp4.result | select sys_id, name
    $dc = @{
      $dcsys_id = $dc_info.sys_id;
      $dcname = $dc_info.name
    }
    #>

    # Collect AC Variables for RITM sys_id
    # URI for AC table + RITM Sys_Id
    $ritm_ac_vars_resource = $ac_vars_table+$($tickets[$i].sys_id)

    # RITMs AC Variables Invoke
    $ac_vars_invoke = Invoke-RestMethod -Method Get -Uri $ritm_ac_vars_resource -ContentType $contenttype -Headers $header

    # AC Variables Result
    $ac_vars_question = $ac_vars_invoke.result

    $question = $ac_vars_question.options_item_option_new.display_value
    $count = $ac_vars_question.options_item_option_new.Count
    $answer = $ac_vars_question.options_value

    $question = $question.replace(' ','')

    for ($x=0; $x -lt $count; $x++) {     

     New-Variable -Name "$($question[$x])_$ticket_number" -Value "$($answer[$x])"
     Write-Host "Variable '$((Get-Variable -Name "$($question[$x])_$ticket_number").Name)' have a value of '$((Get-Variable -Name "$($question[$x])_$ticket_number").Value)'"
     }





    Write-Host "=================="

    }
