param([ValidateSet('garage','junkyard')][string]$Scene,[switch]$TestRoute)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
try{
    if(-not $Scene){
        $form=[Windows.Forms.Form]::new();$form.Text='LIS Remastered navigation prototype';$form.Width=540;$form.Height=240
        $form.StartPosition='CenterScreen';$form.FormBorderStyle='FixedDialog';$form.MaximizeBox=$false;$form.MinimizeBox=$false
        $label=[Windows.Forms.Label]::new();$label.Text='Scene:';$label.SetBounds(20,20,470,24)
        $choices=[Windows.Forms.ComboBox]::new();$choices.AccessibleName='Scene';$choices.DropDownStyle='DropDownList';$choices.SetBounds(20,48,470,28);$choices.TabIndex=0
        [void]$choices.Items.Add("Chloe's house: downstairs and garage");[void]$choices.Items.Add('Junkyard');$choices.SelectedIndex=0
        $test=[Windows.Forms.CheckBox]::new();$test.Text='Run the short navigation test after loading';$test.SetBounds(20,88,470,28);$test.TabIndex=1
        $start=[Windows.Forms.Button]::new();$start.Text='Start isolated test';$start.SetBounds(20,140,200,32);$start.TabIndex=2;$start.DialogResult='OK'
        $cancel=[Windows.Forms.Button]::new();$cancel.Text='Cancel';$cancel.SetBounds(280,140,200,32);$cancel.TabIndex=3;$cancel.DialogResult='Cancel'
        $form.Controls.AddRange(@($label,$choices,$test,$start,$cancel));$form.AcceptButton=$start;$form.CancelButton=$cancel
        $form.Add_Shown({$choices.Focus()})
        if($form.ShowDialog() -ne 'OK'){$form.Dispose();return}
        $Scene=if($choices.SelectedIndex -eq 0){'garage'}else{'junkyard'};$TestRoute=$test.Checked;$form.Dispose()
    }
    $session='profile-probe-play-'+[guid]::NewGuid().ToString('N').Substring(0,12)
    & (Join-Path $PSScriptRoot 'scripts/run_profile_probe.ps1') -SessionName $session -Scene $Scene -Follow:$TestRoute -KeepOpen
}catch{
    [void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Navigation prototype error','OK','Error')
    throw
}
