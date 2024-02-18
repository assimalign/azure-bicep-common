

Get-ChildItem './modules' -Include '*.bicep' -Recurse | ForEach-Object {

    $first, $rest = $_.BaseName -replace 'az.', '' -split '\.'  -Replace '[^0-9A-Z]', ' ' -Split ' ',2
    $name = ($first.Tolower() + (Get-Culture).TextInfo.ToTitleCase($rest) -Replace ' ') + '.bicep'

    Rename-Item $_.FullName -NewName $name

}
