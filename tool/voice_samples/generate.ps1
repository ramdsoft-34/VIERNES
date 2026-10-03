$ErrorActionPreference = 'Stop'
$out = 'C:\Users\melod\AppData\Local\Temp\claude\C--Users-melod-Documents-Claude\8d2cfba5-e34a-41b8-b241-31b7366ee9af\scratchpad\voices'
New-Item -ItemType Directory -Force $out | Out-Null
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType = WindowsRuntime] | Out-Null
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]
function Await($op, $type) {
    $t = $asTask.MakeGenericMethod($type).Invoke($null, @($op))
    $t.Wait() | Out-Null
    $t.Result
}
$synth = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
$phrases = @('Viernes', 'Oye Viernes', 'Viernes.', 'Viernes, por favor', 'Hola Viernes')
$rates = @('90%', '100%', '115%')
$pitches = @('-6%', '+0%', '+6%')
foreach ($v in [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices) {
    if ($v.Language -notlike 'es*') { continue }
    $synth.Voice = $v
    $name = ($v.DisplayName -split ' ')[1]
    $i = 0
    foreach ($p in $phrases) {
        foreach ($r in $rates) {
            foreach ($pi in $pitches) {
                $i++
                $ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='es-ES'><prosody rate='$r' pitch='$pi'>$p</prosody></speak>"
                $stream = Await ($synth.SynthesizeSsmlToStreamAsync($ssml)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
                $reader = New-Object Windows.Storage.Streams.DataReader($stream.GetInputStreamAt(0))
                Await ($reader.LoadAsync([uint32]$stream.Size)) ([uint32]) | Out-Null
                $bytes = New-Object byte[] ([int]$stream.Size)
                $reader.ReadBytes($bytes)
                [IO.File]::WriteAllBytes((Join-Path $out ("raw_{0}_{1:d2}.wav" -f $name, $i)), $bytes)
            }
        }
    }
    Write-Output "$name $i"
}
