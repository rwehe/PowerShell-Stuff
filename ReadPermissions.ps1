#############################################################
# Set $Path to the directory to scan						#
#															#
# Ryan Wehe													#
# ASU FSE													#
# 11/10/2016												#
#############################################################

# This variable sets which CSV file the script reads

$filepath = "E:\Users\rwehe\Documents\PowerShell\Folder_Permissions.csv"

$rowCount = 1 # Starts at 1 due to headers line
$flaggedrowCount = 0
$unflaggedrowCount = 0
$errorCount = 0


function RemoveNTFSPermissions($path, $permission, $accesstype, $object, $inhflag, $propflag ) {
    $FileSystemRights = [System.Security.AccessControl.FileSystemRights]$permission
    $AccessControlType =[System.Security.AccessControl.AccessControlType]::$accesstype
	$InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]$inhflag
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]$propflag	
    $Account = New-Object System.Security.Principal.NTAccount($object)
    $FileSystemAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Account, $FileSystemRights, $InheritanceFlag, $PropagationFlag, $AccessControlType)
    $DirectorySecurity = Get-ACL $path
    $DirectorySecurity.RemoveAccessRuleAll($FileSystemAccessRule)
    Set-ACL $path -AclObject $DirectorySecurity
}

function AddNTFSPermissions($path, $object, $permission) {
    $FileSystemRights = [System.Security.AccessControl.FileSystemRights]$permission
 #   $IsInherited = $true
	$InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]"None"
    $AccessControlType =[System.Security.AccessControl.AccessControlType]::Allow
    $Account = New-Object System.Security.Principal.NTAccount($object)
    $FileSystemAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Account, $FileSystemRights, $InheritanceFlag, $PropagationFlag, $AccessControlType)
    $DirectorySecurity = Get-ACL $path
    $DirectorySecurity.AddAccessRule($FileSystemAccessRule)
    Set-ACL $path -AclObject $DirectorySecurity
}

Import-Csv $filepath |`
	ForEach-Object {
		$rowCount = ($rowCount+1)
#		Checks the Flagged value for True and the Access value to ensure it is one of the following:
#		FullControl; Modify, Synchronize; Read, Synchronize; ReadAndExecute, Synchronize; Write, Synchronize; Write, ReadAndExecute, Synchronize
		If (($_.Flagged -eq $true) -and ($_.FileSystemRights -eq "FullControl" -or $_.FileSystemRights -eq "Modify, Synchronize" -or $_.FileSystemRights -eq "Read, Synchronize" -or $_.FileSystemRights -eq "ReadAndExecute, Synchronize" -or $_.FileSystemRights -eq "Write, Synchronize" -or $_.FileSystemRights -eq "Write, ReadAndExecute, Synchronize")){
			# Sets a variable for the folder path in the flagged line
			$pathToModify = $_.Path
			# Grab current ACL of the flagged line
			$tempACL = Get-ACL $_.Path
			# Put proposed changes into variables
			$IdentityReference = $_.IdentityReference
			$FileSystemRights = $_.FileSystemRights
			
			$tempACL | Select -ExpandProperty Access | 
			
			%{if ($_.IdentityReference -eq $IdentityReference){
				Write-Host "Removing" $_.IdentityReference "from" $pathToModify -BackgroundColor Red -ForegroundColor Black
				RemoveNTFSPermissions $pathToModify $_.FileSystemRights $_.AccessControlType $_.IdentityReference $_.InheritanceFlags $_.PropagationFlags				
			 }
			}			
			AddNTFSPermissions $pathToModify $IdentityReference $FileSystemRights
			Write-Host "ACL Modified - Row:"$rowCount "| Path:" $pathToModify "| IdentityReference:" $IdentityReference "| FileSystemRights:" $FileSystemRights "| Access Control Type:" $accessControlType -BackgroundColor White -ForegroundColor Red
			
			$flaggedrowCount = ($flaggedrowCount+1)			
		}
		ElseIf (($_.Flagged -eq $true) -and ($_.FileSystemRights -eq "remove")){
			Write-Host "Removing" $_.IdentityReference "from" $_.Path -BackgroundColor Red -ForegroundColor Black
			RemoveNTFSPermissions $_.Path $_.FileSystemRights $_.AccessControlType $_.IdentityReference $_.InheritanceFlags $_.PropagationFlags
			$flaggedrowCount = ($flaggedrowCount+1)
		}
		ElseIf ($_.Flagged -eq $true){
			Write-Host "Invalid access detected on row"$rowCount -BackgroundColor Red -ForegroundColor Black
			$errorCount = ($errorCount+1)
		}
		Else{
			#Write-Host "No flagged rows found" -BackgroundColor DarkGreen -ForegroundColor Black
			$unflaggedrowCount = ($unflaggedrowCount+1)
		}
}



Write-Host $flaggedrowCount "flagged |" $unflaggedrowCount "not flagged |" $errorCount "errors"


#####################################################################################################################################
#														Sources:																	#
# http://stackoverflow.com/questions/11465074/powershell-remove-all-permissions-on-a-directory-for-all-users						#
#																																	#
#####################################################################################################################################