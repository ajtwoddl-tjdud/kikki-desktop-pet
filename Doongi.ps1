param([switch]$SelfTest)
$ErrorActionPreference = 'Stop'
$script:petMutex=$null
$script:toggleEvent=$null
if (-not $SelfTest) {
    $created=$false
    $script:petMutex=[Threading.Mutex]::new($true,'Local\Doongi.DesktopPet',[ref]$created)
    if (-not $created) { $script:petMutex.Dispose(); exit 0 }
    $script:toggleEvent=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::AutoReset,'Local\Doongi.ToggleVisibility')
}
$script:hiddenAt=$null
$script:pendingClassEnd=$false
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$script:rng = New-Object Random
. (Join-Path $PSScriptRoot 'Mischief.ps1')
if ($SelfTest) { Set-MischiefLevel 'off' -NoSave } else { Read-MischiefSettings }
$script:mode = 0
$script:auto = $true
$script:nextChange = [DateTime]::Now.AddSeconds(22)
$script:bubbleUntil = [DateTime]::Now.AddSeconds(6)
$script:classEnd = $null
$script:tick = 0
$script:scale = 1.0
$script:motion = $true
$script:clock = [Diagnostics.Stopwatch]::StartNew()
$script:nextBlink = 2.2
$script:blinkEnd = 0.0
$script:attentionStart = -10.0
$script:attentionEnd = 0.0
$script:pressed = $false
$script:dragging = $false
$script:dropStart = $null
$script:nextDrop = $script:rng.Next(120,241)
$script:dropSpoke = $false
$script:expressionEnd = 0.0
$script:nextExpression = $script:rng.Next(120,241)
$script:lookX = 0.0
$script:lookY = 0.0
$script:lastHover = -10.0
$script:lines = @(
    @('야르렁 바나나', '이거 먹고 쪼끔 쉴래.', '바나나는 내가 맡을게.', '천천히 먹어야 오래 먹지.', '이거 쫌 맛있는데?', '한 입만 더. 냠.', '나 간식 먹고 있을게.', '맛있는 건 앉아서 먹어야지.', '한 입 먹고, 쪼끔 쉬고.', '야르. 간식 시간 좋다.'),
    @('누워서 폰 보는 게 젤 편해.', '이것만 보고 쉴게. 아마도.', '야르. 이 자세 좋다.', '나 폰 좀 보고 있을게.', '같이 볼래? 옆으로 와.', '일어나기는 쪼끔 귀찮네.', '쪼끔만 보고 잘래.', '이러다 또 밤 되겠네.', '누울 자리랑 폰만 있으면 됨.', '이것만 보고 잘 거야. 진짜.'),
    @('야르 누워야지.', '쪼끔만 누워 있을게.', '여기서 눈 좀 붙일래.', '나 먼저 잘게. 근처에 있어.', '하암… 졸려…', '편하게 누워서 잘래.', '언제 일어날지 감도 안 옴.', '쪼끔 자고 다시 놀자.', '눈 감고 있어도 나 여기 있어.', '나 깨우지 마… 쫌만…'),
    @('노는 게 젤 좋아.', '나 한 판 하고 있을게.', '이번 판은 쪼끔 집중할게.', '잘하면 박수 한 번 해줘.', '이번 판은 이기고 싶다.', '나 이거 쪼끔만 하고.', '아 쫌만. 지금 중요한 판이야.', '응원해 주면 더 잘할지도.', '컨트롤러 잡았으니까 한 판은 해야지.', '나 지금 열심히 노는 중. 쪼끔 바빠.')
)
$script:extraLines = @{
    hello = @('안녕하숭~', '나 왔다. 뭐 하고 있었어?', '여기 내 자리 남겨뒀지?', '불러줘서 아자스~', '나도 껴.', '오늘도 같이 놀자. 너 끝나면.', '끼끼 왔는데 아무도 안 반겨주네~', '나 왔으니까 쪼끔만 봐줘.', '뭐 해? 나 구경할래.', '왔어? 나도 방금 왔어.')
    drag = @('오. 여기 괜찮네.', '이사 끝~', '여기 내 자리야?', '오. 뷰 바뀌었다.', '여기서 누우면 돼?', '옮겨줘서 아자스~', '나 여기 살아 이제.', '짐은 없어. 나만 오면 돼.', '옆으로 쪼끔만 비켜줘.', '여기도 네 옆이네. 좋다.')
    lift = @('어어. 잠깐만.', '아 왜 들어~', '나 발 안 닿잖아.', '어허. 내려놔.', '살살~ 나 쪼끄매.', '내려주숭…', '나 아직 갈 데 없는데~', '발 좀 닿게 해줘.', '구경 끝났으면 내려줘~', '나 들고 뭐 하게…')
    putDown = @('아자스~', '휴. 이제 됐다.', '다시는 안 들 거지? …진짜?', '나 쫌 놀랐잖아.', '방금 좀 밤티였지… 못 본 척.', '아무튼. 나 쉬던 거 마저 쉴게.', '웃었어? 나 봤는데.', '머리 안 헝클어졌지?', '여기 있을게. 또 들진 말고~', '이제 쪼끔 쉬자.')
    auto = @('너 할 거 해. 난 놀게.', '나 여기 있을게.', '나 혼자 잘 놀아. 봐봐.', '야르. 누울 자리부터 보자.', '오늘도 바쁘게 쉴 예정.', '나도 할 거 있어. 쉬기.', '놀다가 졸리면 잘래.', '쉬는 건 내가 해줄게.', '쪼끔 심심하면 나 봐.', '필요하면 불러. 자면 말고.')
    classStart = @('잘 듣고 와. 난 여기 있을게.', '끝나면 불러줘.', '수업 듣는 동안 옆에 있을게.', '끝나면 같이 쉬자.', '나 여기서 기다릴게.', '가끔 나 봐도 돼. 나 귀엽잖아.')
    classEnd = @('시간 다 됐다. 고생했어.', '야르. 이제 쪼끔 쉬자.', '수고했어. 나 여기 있었지.', '끝날 때 됐네. 기지개 좀 켜.', '고생했으니까 잠깐 쉬어.', '나랑 쪼끔 쉬었다 하자.')
    phoneDrop = @('못 본 척 해줘~~', '안 봤지? 그치?', '방금 거 편집해줘…', '아. 쫌 민망한데.', '쉿. 우리끼리 비밀.', '잠깐 저쪽 좀 봐봐.', '안 봤다고 해주라~~', '나 주울게. 웃지 마~', '아… 눈 마주치지 말자.', '이건 폰이 잘못했어…', '내 손이 쫌 작아서 그래.', '웃지 마. 나도 웃기니까…')
    gameLoss = @('줴줴이야~', '한 판 끝. 아 손 아파.', '오늘 게임은 여기까지. 아마도.', '잠깐 쉬었다 할래.', '나 쫌 열심히 놀았다.', '게임했으니까 쉬어야지.')
    gameCheer = @('오? 나 쫌 하는데?', '봤어? 방금 봤지?', '티~원!', '아 이래서 못 끄지.', '잠깐. 나 지금 진심이야.', '나 소질 있나 봐. 헤헤.')
    walkPoke = @('왜? 뭐? 산책하는 끼끼 처음 봐?', '왜~ 나 걷고 있잖아.', '응? 나 쪼끔만 걷고.', '같이 갈래?', '안 도망가. 산책이야.', '왜? 따라오게?', '봤지? 나 간다~', '응. 너 봤어.', '뭐야. 나 기다려줄까?', '나 저기까지만 갔다 올게.')
    backPoke = @('왜, 뭐?', '응? 불렀어?', '다 들려~', '나 쫌 쉬고 있었는데.', '왜. 보고 싶었어?', '여기 있잖아~', '할 말 없으면 나 다시 쉰다?', '안 갔어. 여기 있어.', '뒤에서 몰래 눌렀지.', '뒤통수도 귀여워?')
    playful = @('메롱.', '히히. 봤어?', '안 본 척해. 나 쑥스러워.', '눈 마주쳤다.', '아 왜 웃어~', '쫌 귀여웠지 방금.', '너 웃으니까 나도 웃겨.', '히히. 또 봐줘.')
    poke = @('응?', '왜 톡 쳐~', '왜? 뭐?', '할 말 있어?', '나 보고 싶었어?', '응. 여기 있어.', '귀엽다고? 아직 말 안 했어?', '너 나 되게 좋아하네.')
    eatPoke = @('왜? 나 먹고 있잖아.', '잠깐. 한 입만.', '야르렁 바나나.', '응? 냠.', '먹을 때 건드리기 있어?', '나 먹는 거 그렇게 재밌어?', '한 입만 더 먹고.', '잠깐. 아직 씹고 있어.', '이거 내 거야~', '듣고 있어. 냠.', '달라고? 쪼끔만 줄 건데.', '한 입 줄까? 진짜 쪼끔인데.')
    phonePoke = @('왜? 나 폰 보고 있었는데.', '응? 이것 좀 봐.', '아 이거 너 보여주고 싶다.', '같이 볼래?', '잠깐. 이것만 보고.', '또 불러~ 나 인기 많네.', '나 이제 진짜 이것만 봐.', '아 일어나기 싫어.', '너도 누워. 쫌 비켜줄게.', '너도 심심해?', '나 지금 쫌 바빠. 누워 있느라.', '왜~ 편하게 누워 있었는데.')
    gamePoke = @('아 잠깐잠깐.', '이거 쪼끔만 하고.', '응? 듣고 있어.', '구경하려고?', '응원해줘. 쫌 크게.', '지금 손 못 놔.', '나 쫌만 봐줘. 잘하나.', '아 지금 중요한데~', '방금 나 봤지? 잘했지?', '노는 데 집중 좀 할게.', '한 판만 더. 진짜로.', '끝나면 놀아줄게~')
    sleepPoke = @('응… 쪼끔만 더…', '왜… 나 자잖아…', '안 잤어… 잤어…', '할 말 없으면 나 잔다…', '일어나면 놀아줄게…', '응… 여기 있어…', '아 들었어… 쿨…', '깨웠으면 책임져… 토닥여줘…', '나 어디 안 가… 쫌 잘게…', '아 이제 막 잠들었는데…', '한 번만 봐준다… 쿨…', '졸려… 이따 불러…')
    walk = @('쫌 걸어야겠다.', '자리 좀 바꿔볼까.', '나 산책 간다~', '저쪽에 뭐 있나 볼래.', '야르. 가보자.', '끼끼 지나갑니다~', '가만히 있었더니 찌뿌둥해.', '쫌 걷고 다시 누워야지.', '편한 자리 찾으러 간다.', '따라와도 돼. 나 쫌 느려.')
}
$script:recentLines = New-Object 'System.Collections.Generic.Queue[string]'
function Say-Random([string]$pool = 'pose', [switch]$Poke) {
    if ($pool -eq 'pose') { $choices = $script:lines[$script:mode] }
    else { $choices = $script:extraLines[$pool] }
    $available = @($choices | Where-Object { -not $script:recentLines.Contains($_) })
    if ($available.Count -eq 0) { $available = @($choices | Where-Object { $_ -ne $script:words.Text }) }
    if ($available.Count -eq 0) { $available = @($choices) }
    $context=if ($pool -eq 'pose' -and $script:mode -eq 3) {'gameStart'} else {$pool}
    $t=$script:clock.Elapsed.TotalSeconds
    $line=Get-MischiefLine $context ($available[$script:rng.Next($available.Count)]) $t ($script:rng.Next(100)) ($script:rng.Next(10000))
    $script:memeFaceEnd=0
    if ($line.isMeme -and $script:mischiefLevel -eq 'normal' -and $script:motion -and $script:mode -ne 2 -and $context -in @('eatPoke','phonePoke','gamePoke','playful','gameCheer')) { $script:memeFaceEnd=$t+1.15 }
    if ($Poke) {
        $memeFace=($script:memeFaceEnd -gt $t)
        Say-Poke $line.text
        if ($null -ne $script:pendingPoke) { $script:pendingPoke.memeFace=$memeFace; $script:memeFaceEnd=0 }
    } else { Say $line.text }
}
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Width="232" Height="270" WindowStyle="None" AllowsTransparency="True" Background="Transparent" Topmost="True" ShowInTaskbar="False" ResizeMode="NoResize" Title="끼끼" UseLayoutRounding="True">
  <Canvas x:Name="Stage" Background="Transparent">
    <Ellipse x:Name="GroundShadow" Canvas.Left="49" Canvas.Top="238" Width="134" Height="10" IsHitTestVisible="False" RenderTransformOrigin="0.5,0.5">
      <Ellipse.Fill><RadialGradientBrush><GradientStop Color="#504B3322" Offset="0"/><GradientStop Color="#004B3322" Offset="1"/></RadialGradientBrush></Ellipse.Fill>
      <Ellipse.RenderTransform><ScaleTransform/></Ellipse.RenderTransform>
    </Ellipse>
    <Grid x:Name="Bubble" Canvas.Top="4" Canvas.Left="10" Width="212" IsHitTestVisible="False" RenderTransformOrigin="0.42,1">
      <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="14"/></Grid.RowDefinitions>
      <Grid.RenderTransform><ScaleTransform/></Grid.RenderTransform>
      <Grid.Effect><DropShadowEffect Color="#503522" BlurRadius="5" ShadowDepth="2" Opacity="0.16"/></Grid.Effect>
      <Border Grid.Row="0" MinHeight="44" CornerRadius="19" Background="#FFFEF8" BorderBrush="#694A34" BorderThickness="1.7" Padding="11,9">
        <TextBlock x:Name="Words" Text="왔음. 여기 누울게." FontFamily="Malgun Gothic" FontSize="14" FontWeight="SemiBold" Foreground="#493020" TextAlignment="Center" TextWrapping="Wrap" LineHeight="19"/>
      </Border>
      <Path Grid.Row="1" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="77,-2,0,0" Data="M 0,0 L 12,14 Q 14,8 21,0" Fill="#FFFEF8" Stroke="#694A34" StrokeThickness="1.7" StrokeLineJoin="Round"/>
    </Grid>
    <Image x:Name="Pet" Canvas.Left="6" Canvas.Top="65" Width="220" Height="195" Stretch="Uniform" RenderTransformOrigin="0.5,1" Cursor="Hand">
      <Image.RenderTransform><TransformGroup><ScaleTransform/><RotateTransform/><TranslateTransform/><SkewTransform/></TransformGroup></Image.RenderTransform>
    </Image>
    <Image x:Name="RestBlend" Canvas.Left="6" Canvas.Top="65" Width="220" Height="195" Stretch="Uniform" RenderTransformOrigin="0.5,1" IsHitTestVisible="False" Visibility="Hidden"/>
    <Image x:Name="FallingPhone" Canvas.Left="6" Canvas.Top="65" Width="220" Height="195" Stretch="Uniform" IsHitTestVisible="False" Visibility="Hidden">
      <Image.RenderTransform><TranslateTransform/></Image.RenderTransform>
    </Image>
    <TextBlock x:Name="SleepMark" Canvas.Left="172" Canvas.Top="110" Text="z z" FontFamily="Comic Sans MS" FontSize="17" Foreground="#8B6C51" IsHitTestVisible="False" Visibility="Hidden"/>
  </Canvas>
</Window>
'@
$reader = New-Object System.Xml.XmlNodeReader $xaml
$script:window = [Windows.Markup.XamlReader]::Load($reader)
$script:pet = $window.FindName('Pet')
$script:bubble = $window.FindName('Bubble')
$script:words = $window.FindName('Words')
$script:sleepMark = $window.FindName('SleepMark')
$script:fallingPhone = $window.FindName('FallingPhone')
$script:groundShadow = $window.FindName('GroundShadow')
$bitmap = New-Object Windows.Media.Imaging.BitmapImage
$bitmap.BeginInit()
$bitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$bitmap.UriSource = [Uri](Join-Path $PSScriptRoot 'assets/doongi.png')
$bitmap.EndInit()
$bitmap.Freeze()
$script:sprites = @()
$cw = [int]($bitmap.PixelWidth / 2)
$ch = [int]($bitmap.PixelHeight / 2)
for ($i=0; $i -lt 4; $i++) {
    $rect = New-Object Windows.Int32Rect (($i % 2)*$cw), ([int][Math]::Floor($i/2)*$ch), $cw, $ch
    $sprite = New-Object Windows.Media.Imaging.CroppedBitmap $bitmap, $rect
    $sprite.Freeze()
    $script:sprites += $sprite
}
$blinkBitmap = New-Object Windows.Media.Imaging.BitmapImage
$blinkBitmap.BeginInit()
$blinkBitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$blinkBitmap.UriSource = [Uri](Join-Path $PSScriptRoot 'assets/doongi-blink.png')
$blinkBitmap.EndInit()
$blinkBitmap.Freeze()
$script:blinkSprites = @()
$bw = [int]($blinkBitmap.PixelWidth/2)
$bh = [int]($blinkBitmap.PixelHeight/2)
for ($i=0; $i -lt 4; $i++) {
    $rect = [Windows.Int32Rect]::new(($i%2)*$bw,[int][Math]::Floor($i/2)*$bh,$bw,$bh)
    $frame = [Windows.Media.Imaging.CroppedBitmap]::new($blinkBitmap,$rect)
    $frame.Freeze()
    $script:blinkSprites += $frame
}
$playfulBitmap = New-Object Windows.Media.Imaging.BitmapImage
$playfulBitmap.BeginInit()
$playfulBitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$playfulBitmap.UriSource = [Uri](Join-Path $PSScriptRoot 'assets/doongi-playful.png')
$playfulBitmap.EndInit()
$playfulBitmap.Freeze()
$script:playfulSprites = @()
$pw=[int]($playfulBitmap.PixelWidth/2); $ph=[int]($playfulBitmap.PixelHeight/2)
for ($i=0; $i -lt 4; $i++) {
    $frame=[Windows.Media.Imaging.CroppedBitmap]::new($playfulBitmap,[Windows.Int32Rect]::new(($i%2)*$pw,[int][Math]::Floor($i/2)*$ph,$pw,$ph))
    $frame.Freeze()
    $script:playfulSprites += $frame
}
$lookBitmap = New-Object Windows.Media.Imaging.BitmapImage
$lookBitmap.BeginInit()
$lookBitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$lookBitmap.UriSource = [Uri](Join-Path $PSScriptRoot 'assets/doongi-look.png')
$lookBitmap.EndInit()
$lookBitmap.Freeze()
$script:lookSprites = @()
$lw=[int]($lookBitmap.PixelWidth/2); $lh=[int]($lookBitmap.PixelHeight/2)
for ($i=0; $i -lt 4; $i++) {
    $frame=[Windows.Media.Imaging.CroppedBitmap]::new($lookBitmap,[Windows.Int32Rect]::new(($i%2)*$lw,[int][Math]::Floor($i/2)*$lh,$lw,$lh))
    $frame.Freeze()
    $script:lookSprites += $frame
}
function React-ToPoke([double]$t) {
    if (Start-RepeatPoke $t) { return }
    if ($null -ne $script:cameraScene) {
        $script:attentionStart=$t; $script:attentionEnd=$t+1.0
        Say-Random ($script:cameraScene.kind+'Poke') -Poke
        return
    }
    if ($null -ne $script:roam) {
        if ($null -eq $script:roam.pausedAt) { $script:roam.pausedAt=$t }
        $script:roam.pauseUntil=$t+1.0
        $script:attentionStart=$t; $script:attentionEnd=$t+1.0
        Say-Random 'walkPoke' -Poke
        $script:roam.replyText=if ($null -eq $script:pendingPoke) { $script:words.Text } else { $null }
        if ($null -eq $script:pendingPoke) { $script:bubbleUntil=[DateTime]::Now.AddSeconds(1.0) }
        return
    }
    if ($null -ne $script:backTurn) {
        $script:backTurn.peek=$t
        $script:backTurn.until=[Math]::Max($script:backTurn.until,$t+5)
        $script:attentionStart=$t; $script:attentionEnd=$t+2.6
        Say-Random 'backPoke' -Poke
        $script:bubbleUntil=[DateTime]::Now.AddSeconds(3)
        return
    }
    $script:sulkEnd=0
    Stop-Rest $t
    if ($null -ne $script:roam) { Stop-Roam $t }
    $script:attentionStart=$t
    $script:attentionEnd=$t+2.3
    $script:expressionEnd=0
    $script:nextExpression=$t+$script:rng.Next(120,241)
    $script:dropStart=$null
    $script:nextDrop=$t+$script:rng.Next(120,241)
    $script:fallingPhone.Visibility='Hidden'
    if ($script:nextChange -lt [DateTime]::Now.AddSeconds(4)) { $script:nextChange=[DateTime]::Now.AddSeconds(4) }
    Say-Random (@('eatPoke','phonePoke','sleepPoke','gamePoke')[$script:mode]) -Poke
    $script:bubbleUntil=[DateTime]::Now.AddSeconds(3)
}
function Play-Expression([double]$t) {
    if ($null -ne $script:poseTransition) { return }
    if ($null -ne $script:backTurn) { return }
    if ($script:mode -eq 2 -or $null -ne $script:dropStart -or $null -ne $script:roam -or $null -ne $script:rest -or $t -lt $script:attentionEnd) { return }
    $script:expressionEnd=$t+1.15
    $script:quietUntil=$t+1.15+(Get-ActivitySeconds $script:mode)
    $script:nextExpression=$t+$script:rng.Next(120,241)
}
$dropBitmap = New-Object Windows.Media.Imaging.BitmapImage
$dropBitmap.BeginInit()
$dropBitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$dropBitmap.UriSource = [Uri](Join-Path $PSScriptRoot 'assets/doongi-phone-drop.png')
$dropBitmap.EndInit()
$dropBitmap.Freeze()
$script:dropSprites = @()
# The generated atlas has wider left-hand poses; preserve the full tails.
$dw=$dropBitmap.PixelWidth; $dh=$dropBitmap.PixelHeight
$split=[int]($dw*0.5263); $half=[int]($dh/2)
$rects=@(
    [Windows.Int32Rect]::new(0,0,$split,$half),
    [Windows.Int32Rect]::new([int]($dw/2),0,[int]($dw/2),$half),
    [Windows.Int32Rect]::new(0,$half,$split,$half),
    [Windows.Int32Rect]::new($split,$half,$dw-$split,$half)
)
for ($i=0; $i -lt 4; $i++) {
    $frame=[Windows.Media.Imaging.CroppedBitmap]::new($dropBitmap,$rects[$i])
    $frame.Freeze()
    $script:dropSprites += $frame
}
$script:fallingPhone.Source=$script:dropSprites[1]
function Start-PhoneDrop([double]$t) {
    Stop-Rest $t
    $script:quietUntil=$t+5.6+(Get-ActivitySeconds $script:mode)
    $script:pickupStage=-1
    $script:dropStart=$t
    $script:dropSpoke=$false
    # Let the small scene finish before the automatic pose switch.
    if ($script:nextChange -lt [DateTime]::Now.AddSeconds(6)) { $script:nextChange=[DateTime]::Now.AddSeconds(6) }
}
function Animate-Pet([double]$t) {
    $script:pet.Opacity=1
    $script:restBlend.Visibility='Hidden'
    $attentive=($t -ge $script:attentionStart -and $t -lt $script:attentionEnd)
    if ($t -ge $script:nextBlink) {
        $script:blinkEnd=$t+0.14
        $script:nextBlink=$t+2.4+$script:rng.NextDouble()*3.6
    }
    $closed=($t -lt $script:blinkEnd)
    $sx=1.0; $sy=1.0; $angle=0.0; $x=0.0; $y=0.0
    if ($script:motion) {
        switch ($script:mode) {
            0 {
                # Barely visible chewing with long quiet pauses.
                $chew=([Math]::Sin($t*4)*[Math]::Max(0,[Math]::Sin($t*0.45)))
                $sy=1+0.004*$chew
            }
            1 {
                # Stay still while watching, with only a tiny sleepy nod.
                $nod=[Math]::Pow([Math]::Max(0,[Math]::Sin($t*0.38)),12)
                $angle=0.6*$nod
                $sy=1+0.003*[Math]::Sin($t*1.1)
                if ($nod -gt 0.7) { $closed=$true }
            }
            2 {
                $sy=1+0.006*[Math]::Sin($t*1.2)
                $sx=1-0.002*[Math]::Sin($t*1.2)
            }
            3 {
                # Occasional small shifts, without constant rocking or hopping.
                $burst=[Math]::Pow([Math]::Max(0,[Math]::Sin($t*0.5)),8)
                $angle=0.35*$burst*[Math]::Sin($t*3)
                $y=-0.5*$burst*[Math]::Abs([Math]::Sin($t*3))
                $sy=1+0.003*[Math]::Sin($t*1.1)
            }
        }
    }
    if ($closed -and $script:mode -ne 2) { $script:pet.Source=$script:blinkSprites[$script:mode] }
    else { $script:pet.Source=$script:sprites[$script:mode] }
    if ((Get-DueDetail $t) -eq 'expression') {
        Play-Expression $t
        if ($script:mode -eq 3) { Say-Random 'gameCheer' } else { Say-Random 'playful' }
    }
    if ($t -lt $script:expressionEnd -and $script:mode -ne 2) { $script:pet.Source=$script:playfulSprites[$script:mode] }
    $script:fallingPhone.Visibility='Hidden'
    if ($script:mode -eq 1 -and $script:motion -and -not $script:dragging -and -not $attentive -and $null -eq $script:roam -and $null -eq $script:rest -and $null -eq $script:backTurn) {
        if ($null -eq $script:dropStart -and (Get-DueDetail $t) -eq 'drop') { Start-PhoneDrop $t }
        if ($null -ne $script:dropStart) {
            $dt=$t-$script:dropStart
            if ($script:chaosEnabled) { $dt*=2.0 }
            $sx=1; $sy=1; $angle=0; $y=0
            if ($dt -lt 0.65) {
                $script:pet.Source=$script:blinkSprites[1]
                $angle=3*[Math]::Sin($dt/0.65*[Math]::PI)
            } elseif ($dt -lt 1.02) {
                $script:pet.Source=$script:dropSprites[0]
                $script:fallingPhone.Visibility='Visible'
                $p=($dt-0.65)/0.37
                $script:fallingPhone.RenderTransform.X=-15*$p*$p
                $script:fallingPhone.RenderTransform.Y=12*$p*$p
            } elseif ($dt -lt 1.55) {
                $script:pet.Source=$script:dropSprites[2]
                $impact=($dt-1.02)/0.53
                $angle=4*[Math]::Sin($impact*14)*(1-$impact)
                $sy=1-0.045*[Math]::Sin($impact*[Math]::PI)
            } elseif ($dt -lt 3.2) {
                $script:pet.Source=$script:dropSprites[3]
                $script:fallingPhone.Visibility='Visible'
                $script:fallingPhone.RenderTransform.X=47
                $script:fallingPhone.RenderTransform.Y=68
                if (-not $script:dropSpoke) { Say-Random 'phoneDrop'; $script:dropSpoke=$true }
            } elseif ($dt -lt 5.6) {
                Update-PhonePickup $dt
            } else {
                $script:dropStart=$null
                $script:nextDrop=$t+$script:rng.Next(120,241)
            }
        }
    } elseif ($null -ne $script:dropStart) {
        $script:dropStart=$null
        $script:nextDrop=$t+$script:rng.Next(120,241)
    }
    # Small damped perspective shifts make the pet respond to nearby movement.
    $targetX=0.0; $targetY=0.0
    if ($script:motion -and $script:mode -ne 2 -and $null -eq $script:dropStart -and -not $script:dragging -and -not $attentive -and -not $SelfTest) {
        $pointer=[Windows.Input.Mouse]::GetPosition($script:window)
        $dx=$pointer.X/$script:scale-116
        $dy=$pointer.Y/$script:scale-165
        $distance=[Math]::Sqrt($dx*$dx+$dy*$dy)
        if ($distance -lt 290) {
            $attention=[Math]::Min(1,(290-$distance)/100)
            $targetX=[Math]::Max(-1,[Math]::Min(1,$dx/120))*$attention
            $targetY=[Math]::Max(-1,[Math]::Min(1,$dy/100))*$attention
        }
    }
    $script:lookX+=($targetX-$script:lookX)*0.045
    $script:lookY+=($targetY-$script:lookY)*0.045
    $skew=0.0
    if ($script:motion -and $null -eq $script:dropStart) {
        $angle+=0.5*$script:lookX
        $x+=0.6*$script:lookX
        $y+=0.35*$script:lookY
        $sx*=1-0.003*[Math]::Abs($script:lookX)
        $skew=-0.4*$script:lookX
    }
    if ($attentive) {
        if ($script:motion -and $script:mischiefLevel -eq 'normal' -and $t -lt $script:memeFaceEnd) { $script:pet.Source=$script:playfulSprites[$script:mode] }
        else { $script:pet.Source=$script:lookSprites[$script:mode] }
        $still=[Math]::Min(1,[Math]::Min(($t-$script:attentionStart)/0.16,($script:attentionEnd-$t)/0.25))
        $sx=1+($sx-1)*(1-$still); $sy=1+($sy-1)*(1-$still)
        $angle*=1-$still; $x*=1-$still; $y*=1-$still; $skew*=1-$still
    }
    $shadowHeight=@(241,228,220,229)[$script:mode]
    [Windows.Controls.Canvas]::SetTop($script:groundShadow,$shadowHeight)
    $lift=[Math]::Max(0,-$y)
    $script:groundShadow.RenderTransform.ScaleX=1-[Math]::Min(0.25,$lift/90)
    $script:groundShadow.Opacity=0.85-[Math]::Min(0.4,$lift/40)
    $transforms=$script:pet.RenderTransform.Children
    $transforms[0].ScaleX=$sx; $transforms[0].ScaleY=$sy
    $transforms[1].Angle=$angle
    $transforms[2].X=$x; $transforms[2].Y=$y
    $transforms[3].AngleX=$skew
    if ($script:mode -eq 2 -and $script:motion -and -not $attentive) {
        $script:sleepMark.Visibility='Visible'
        $phase=($t%5)/5
        [Windows.Controls.Canvas]::SetTop($script:sleepMark,125-12*$phase)
        $script:sleepMark.Opacity=0.65*[Math]::Sin($phase*[Math]::PI)
    } else { $script:sleepMark.Visibility='Hidden' }
}
$script:bubbleHeadCache=@{}
$script:lastBubbleSource=$null
$script:lastBubbleMessage=$null
Add-Type @'
public static class KikkiBubbleSilhouette {
 public static int Top(byte[] pixels,int width,int height) {
  bool[] visited=new bool[width*height]; int[] queue=new int[width*height];
  int bestCount=0,bestTop=0;
  for(int seed=0;seed<visited.Length;seed++) {
   if(visited[seed] || pixels[seed*4+3]<=32) continue;
   int read=0,write=1,top=height; queue[0]=seed; visited[seed]=true;
   while(read<write) {
    int p=queue[read++],x=p%width,y=p/width; if(y<top) top=y;
    for(int dy=-1;dy<=1;dy++) for(int dx=-1;dx<=1;dx++) {
     int nx=x+dx,ny=y+dy; if(nx<0||nx>=width||ny<0||ny>=height) continue;
     int n=ny*width+nx; if(visited[n]||pixels[n*4+3]<=32) continue;
     visited[n]=true; queue[write++]=n;
    }
   }
   if(write>bestCount) {bestCount=write;bestTop=top;}
  }
  return bestTop;
 }
}
'@
function Update-BubblePosition {
    if ($script:bubble.Visibility -ne 'Visible' -or $null -eq $script:pet.Source) { return }
    $source=$script:pet.Source
    if ([Object]::ReferenceEquals($source,$script:lastBubbleSource) -and $script:words.Text -eq $script:lastBubbleMessage) { return }
    if (-not $script:bubbleHeadCache.ContainsKey($source)) {
        # Measure the visible silhouette once, including transparent atlas margins.
        $fit=[Math]::Min(220.0/$source.Width,195.0/$source.Height)
        $w=$source.Width*$fit; $h=$source.Height*$fit
        $visual=[Windows.Media.DrawingVisual]::new(); $ctx=$visual.RenderOpen()
        $ctx.DrawImage($source,[Windows.Rect]::new((220-$w)/2,(195-$h)/2,$w,$h)); $ctx.Close()
        $render=[Windows.Media.Imaging.RenderTargetBitmap]::new(220,195,96,96,[Windows.Media.PixelFormats]::Pbgra32)
        $render.Render($visual)
        $pixels=New-Object byte[] (220*195*4)
        $render.CopyPixels($pixels,220*4,0)
        $headTop=[KikkiBubbleSilhouette]::Top($pixels,220,195)
        $script:bubbleHeadCache[$source]=65+$headTop
    }
    $script:bubble.Measure([Windows.Size]::new(212,[double]::PositiveInfinity))
    $top=[Math]::Max(4,$script:bubbleHeadCache[$source]-6-$script:bubble.DesiredSize.Height)
    [Windows.Controls.Canvas]::SetTop($script:bubble,$top)
    $script:lastBubbleSource=$source
    $script:lastBubbleMessage=$script:words.Text
}
function Say([string]$message) {
    $script:pendingPoke=$null
    $script:words.Text = $message
    $script:recentLines.Enqueue($message)
    while ($script:recentLines.Count -gt 5) { [void]$script:recentLines.Dequeue() }
    $script:bubble.Visibility = 'Visible'
    $pop = [Windows.Media.Animation.DoubleAnimation]::new(0.88,1.0,[Windows.Duration]::new([TimeSpan]::FromMilliseconds(180)))
    $ease = [Windows.Media.Animation.QuadraticEase]::new()
    $ease.EasingMode = 'EaseOut'
    $pop.EasingFunction = $ease
    $script:bubble.RenderTransform.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty,$pop)
    $script:bubble.RenderTransform.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty,$pop)
    $script:bubbleUntil = [DateTime]::Now.AddSeconds(6)
    Update-BubblePosition
}
function Set-Pose([int]$index, [switch]$Immediate) {
    $script:cameraScene=$null; $script:pokeScene=$null
    $script:pokeCount=0; $script:lastPokeAt=-10.0
    $previousMode=$script:mode; $previousSource=$script:pet.Source
    if ($previousMode -ne $index) { $script:previousActivity=$previousMode }
    $script:poseTransition=$null
    Stop-BackTurn $script:clock.Elapsed.TotalSeconds
    $script:sulkEnd=0
    Stop-Rest $script:clock.Elapsed.TotalSeconds
    if ($null -ne $script:roam) { Stop-Roam $script:clock.Elapsed.TotalSeconds }
    $script:mode = $index
    $script:attentionEnd=0
    $script:expressionEnd=0; $script:memeFaceEnd=0
    $script:dropStart=$null
    $script:fallingPhone.Visibility='Hidden'
    $script:pet.Source = $script:sprites[$index]
    $script:nextChange = [DateTime]::Now.AddSeconds((Get-ActivitySeconds $index))
    if (-not $SelfTest -and -not $Immediate) { Start-PostureTransition $previousMode $index $script:clock.Elapsed.TotalSeconds $previousSource }
}
function Keep-OnScreen {
    $area = [System.Windows.SystemParameters]::WorkArea
    $script:window.Left = [Math]::Max($area.Left, [Math]::Min($script:window.Left, $area.Right-$script:window.Width))
    $script:window.Top = [Math]::Max($area.Top, [Math]::Min($script:window.Top, $area.Bottom-$script:window.Height))
}
. (Join-Path $PSScriptRoot 'Behavior.ps1')
. (Join-Path $PSScriptRoot 'Roaming.ps1')
. (Join-Path $PSScriptRoot 'Resting.ps1')
. (Join-Path $PSScriptRoot 'Pickup.ps1')
. (Join-Path $PSScriptRoot 'Lifting.ps1')
. (Join-Path $PSScriptRoot 'BackTurn.ps1')
. (Join-Path $PSScriptRoot 'Transitions.ps1')
. (Join-Path $PSScriptRoot 'Runtime.ps1')
. (Join-Path $PSScriptRoot 'Pomodoro.ps1')
. (Join-Path $PSScriptRoot 'Chaos.ps1')
Set-Pose 1 -Immediate
$area = [System.Windows.SystemParameters]::WorkArea
$window.Left = $area.Right - $window.Width - 24
$window.Top = $area.Bottom - $window.Height - 12
$script:homeX=$window.Left
$script:nextRoam=$script:clock.Elapsed.TotalSeconds+$script:rng.Next(120,241)
$pet.Add_MouseEnter({
    $t=$script:clock.Elapsed.TotalSeconds
    if ($t-$script:lastHover -gt 90 -and $t -ge $script:nextExpression -and $script:rng.Next(4) -eq 0) { Play-Expression $t; $script:lastHover=$t }
})
$pet.Add_MouseLeftButtonDown({
    $script:pendingPoke=$null
    $script:poseTransition=$null
    Stop-Rest $script:clock.Elapsed.TotalSeconds
    if ($null -ne $script:roam) { $script:roam.pausedAt=$script:clock.Elapsed.TotalSeconds }
    $script:pressPoint=[Windows.Input.Mouse]::GetPosition($script:window)
    $script:dragOriginTop=$script:window.Top
    $script:lifted=$false
    $script:sulkEnd=0
    $script:pressed=$true
    [void]$script:pet.CaptureMouse()
})
$pet.Add_MouseMove({
    if (-not $script:pressed) { return }
    if ([Windows.Input.Mouse]::LeftButton -ne 'Pressed') { End-PetDrag $script:clock.Elapsed.TotalSeconds; return }
    $point=[Windows.Input.Mouse]::GetPosition($script:window)
    $dx=$point.X-$script:pressPoint.X; $dy=$point.Y-$script:pressPoint.Y
    if (-not $script:dragging -and [Math]::Abs($dx)+[Math]::Abs($dy) -le 6) { return }
    $script:dragging=$true
    Stop-Roam $script:clock.Elapsed.TotalSeconds 240
    Stop-BackTurn $script:clock.Elapsed.TotalSeconds
    $script:attentionEnd=0
    $script:window.Left+=$dx
    $script:window.Top+=$dy
    Track-PetLift $script:clock.Elapsed.TotalSeconds
})
$pet.Add_MouseLeftButtonUp({
    if (-not $script:pressed) { return }
    End-PetDrag $script:clock.Elapsed.TotalSeconds
})
$pet.Add_LostMouseCapture({
    if ($script:pressed -or $script:dragging) { End-PetDrag $script:clock.Elapsed.TotalSeconds -Cancel }
})
$menu = New-Object Windows.Controls.ContextMenu
function Add-Menu([string]$label, [scriptblock]$action) {
    $item = New-Object Windows.Controls.MenuItem
    $item.Header = $label
    $item.Add_Click({
        param($sender,$eventArgs)
        if ($script:chaosEnabled -and [string]$sender.Header -notmatch '^(뽀모도로|크기 바꾸기|끼끼 퇴근)') { Set-ChaosEnabled $false -Quiet }
        if ([string]$sender.Header -notmatch '^(뽀모도로|크기 바꾸기)') { $script:cameraScene=$null; $script:pokeScene=$null }
    })
    $item.Add_Click($action)
    $item.Add_Click({ Sync-PetTimers })
    [void]$menu.Items.Add($item)
}
Add-Menu '알아서 놀기' { $script:auto=$true; if ($script:mode -eq 2) { Say '응… 나 쪼끔만 더 잘래.' } else { Say-Random 'auto' } }
Add-Menu '바나나 먹기' { $script:auto=$false; Set-Pose 0; Say-Random }
Add-Menu '폰 보기' { $script:auto=$false; Set-Pose 1; Say-Random }
Add-Menu '셀카 찍기' { $script:motion=$true; Start-CameraScene 'selfie' $script:clock.Elapsed.TotalSeconds }
Add-Menu '릴스 찍기' { $script:motion=$true; Start-CameraScene 'reels' $script:clock.Elapsed.TotalSeconds }
$script:chaosMenu=New-Object Windows.Controls.MenuItem
$script:chaosMenu.Header='야랄 모드 · 3초마다 난리 나기'
$script:chaosMenu.IsCheckable=$true
$script:chaosMenu.Add_Click({ Set-ChaosEnabled (-not $script:chaosEnabled); Sync-PetTimers })
[void]$menu.Items.Add($script:chaosMenu)
Add-Menu '폰 보다가 꾸벅…' { $script:auto=$false; $script:motion=$true; Set-Pose 1 -Immediate; Start-PhoneDrop $script:clock.Elapsed.TotalSeconds }
Add-Menu '낮잠 자기' { $script:auto=$false; Set-Pose 2; Say-Random }
Add-Menu '누워서 자세 고치기' { $script:motion=$true; $script:auto=$false; Set-Pose 2 -Immediate; Start-Rest $script:clock.Elapsed.TotalSeconds }
Add-Menu '바나나 한 입 먹기' { $script:motion=$true; Set-Pose 0 -Immediate; Start-Rest $script:clock.Elapsed.TotalSeconds }
Add-Menu '게임하기' { $script:auto=$false; Set-Pose 3; Say-Random }
Add-Menu '등 돌리고 쉬기' { Start-BackTurn $script:clock.Elapsed.TotalSeconds }
Add-Menu '윙크 한 번 해봐' { Set-Pose 0 -Immediate; Play-Expression $script:clock.Elapsed.TotalSeconds; Say '윙크. 너한테 해준 거야. 헤헤.' }
Add-Menu '메롱 해봐' { Set-Pose 3 -Immediate; Play-Expression $script:clock.Elapsed.TotalSeconds; Say '메롱. 쪼끔 킹받지? 헤헤.' }
Add-Menu '움직임 줄이기 / 다시 신나게' { $script:motion = -not $script:motion; Say '이 정도 텐션 어때.' }
$script:mischiefMenu=New-Object Windows.Controls.MenuItem
$script:mischiefMenu.Header='킹받기 조절'
foreach ($entry in @(@('normal','기본'),@('mild','순한맛'),@('off','끄기'))) {
    $item=New-Object Windows.Controls.MenuItem
    $item.Header=$entry[1]; $item.Tag=$entry[0]; $item.IsCheckable=$true
    $item.IsChecked=($script:mischiefLevel -eq $entry[0])
    $item.Add_Click({
        param($sender,$eventArgs)
        $message=switch ([string]$sender.Tag) {
            'normal' {'알겠어. 쪼끔 킹받게 해볼게.'}
            'mild' {'응. 가끔만 장난칠게.'}
            'off' {'알았어. 순하게 옆에 있을게.'}
        }
        try { Set-MischiefLevel ([string]$sender.Tag) }
        catch { $message='이번 실행에는 적용했어. 저장은 못 했네.' }
        foreach ($option in $script:mischiefMenu.Items) { $option.IsChecked=($option.Tag -eq $script:mischiefLevel) }
        Say $message
        Sync-PetTimers
    })
    [void]$script:mischiefMenu.Items.Add($item)
}
[void]$menu.Items.Add($script:mischiefMenu)
Add-Menu '근처로 산책 가봐' { $script:motion=$true; $script:roamEnabled=$true; Start-Roam $script:clock.Elapsed.TotalSeconds }
Add-Menu '반대쪽 끝까지 산책 가봐' { $script:motion=$true; $script:roamEnabled=$true; Start-Roam $script:clock.Elapsed.TotalSeconds -Across }
Add-Menu '자동 산책 켜기 / 끄기' {
    $script:roamEnabled=-not $script:roamEnabled
    if ($script:roamEnabled) { $script:nextRoam=$script:clock.Elapsed.TotalSeconds+(Get-ActivitySeconds $script:mode); Say '편한 자리 좀 찾아볼게.' }
    else { Stop-Roam $script:clock.Elapsed.TotalSeconds; Say '응. 여기서 쉬고 있을게.' }
}
[void]$menu.Items.Add((New-Object Windows.Controls.Separator))
Add-Menu '뽀모도로 설정 · 시작' { Show-PomodoroSettings }
Add-Menu '뽀모도로 남은 시간' {
    Update-Pomodoro
    if ($null -ne $script:pomodoro) { Say (Get-PomodoroRemaining) } else { Say '돌아가는 뽀모도로는 없어. 먼저 시작해 줘.' }
}
Add-Menu '뽀모도로 일시정지 / 계속' { Toggle-PomodoroPause }
Add-Menu '뽀모도로 끝내기' { Stop-Pomodoro }
[void]$menu.Items.Add((New-Object Windows.Controls.Separator))
Add-Menu '크기 바꾸기 · 작게 / 크게' {
    Stop-Roam $script:clock.Elapsed.TotalSeconds
    if ($script:scale -eq 1.0) { $script:scale=0.75 } else { $script:scale=1.0 }
    $window.FindName('Stage').LayoutTransform = [Windows.Media.ScaleTransform]::new($script:scale,$script:scale)
    $script:window.Width=232*$script:scale; $script:window.Height=270*$script:scale
    Keep-OnScreen
}
Add-Menu '끼끼 퇴근' { $script:window.Close() }
$pet.ContextMenu = $menu
function Toggle-PetVisibility {
    if ($null -ne $script:pomoDialog) { $script:pomoDialog.Close() }
    if ($script:window.IsVisible) {
        $script:pendingPoke=$null
        if ($script:pressed -or $script:dragging) { End-PetDrag $script:clock.Elapsed.TotalSeconds -Cancel }
        $script:pet.ContextMenu.IsOpen=$false
        $script:hiddenAt=[DateTime]::Now
        $script:clock.Stop()
        $script:window.Hide()
        [Console]::WriteLine('VISIBILITY: hidden')
    } else {
        if ($null -ne $script:hiddenAt) {
            $script:nextChange=$script:nextChange.Add([DateTime]::Now-$script:hiddenAt)
        }
        $script:hiddenAt=$null
        $script:window.ShowActivated=$false
        $script:window.Show()
        $script:clock.Start()
        Present-PomodoroNotice
        if ($script:pendingClassEnd) {
            Say-Random 'classEnd'
            $script:bubbleUntil=[DateTime]::Now.AddSeconds(12)
            $script:pendingClassEnd=$false
        }
        [Console]::WriteLine('VISIBILITY: shown')
    }
    Complete-ClassTimer
    Sync-PetTimers
}
$script:timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(33)
$timer.Add_Tick({
    $now = [DateTime]::Now
    Update-Pomodoro
    Update-PokeFollowup
    if ($script:window.IsVisible) {
        $script:tick++
        Update-Chaos $script:clock.Elapsed.TotalSeconds
        if (-not $SelfTest -and (Get-DueDetail $script:clock.Elapsed.TotalSeconds) -eq 'camera' -and -not $script:pet.ContextMenu.IsOpen) {
            Start-CameraScene (@('selfie','reels')[$script:rng.Next(2)]) $script:clock.Elapsed.TotalSeconds
        }
        Animate-Pet $script:clock.Elapsed.TotalSeconds
        Update-Rest $script:clock.Elapsed.TotalSeconds
        Update-Roam $script:clock.Elapsed.TotalSeconds
        Update-BackTurn $script:clock.Elapsed.TotalSeconds
        Render-PostureTransition $script:clock.Elapsed.TotalSeconds
        Render-CameraScene $script:clock.Elapsed.TotalSeconds
        Render-RepeatPoke $script:clock.Elapsed.TotalSeconds
        Render-PetLift $script:clock.Elapsed.TotalSeconds
        Update-BubblePosition
        if ($now -gt $script:bubbleUntil) { $script:bubble.Visibility='Hidden' }
        if (-not $script:chaosEnabled -and $null -eq $script:cameraScene -and $script:auto -and -not $script:pressed -and -not $script:dragging -and $script:clock.Elapsed.TotalSeconds -ge $script:sulkEnd -and $null -eq $script:roam -and $null -eq $script:rest -and $null -eq $script:backTurn -and $null -eq $script:poseTransition -and $null -eq $script:dropStart -and $script:clock.Elapsed.TotalSeconds -ge $script:expressionEnd -and $script:clock.Elapsed.TotalSeconds -ge $script:attentionEnd -and $now -gt $script:nextChange) {
            Continue-Life

        }
    }
    Complete-ClassTimer
    Sync-PetTimers
})
$script:classTimer = New-Object Windows.Threading.DispatcherTimer
$script:classTimer.Add_Tick({
    $script:classTimer.Stop()
    $script:scheduledClassEnd=$null
    Complete-ClassTimer
    Sync-PetTimers
})
$window.Add_Closed({
    $script:timer.Stop()
    $script:classTimer.Stop()
    $script:pomoTimer.Stop()
    if ($null -ne $script:visibilityWatcher) { $script:visibilityWatcher.Dispose() }
})
if ($SelfTest) {
    for ($i=0; $i -lt 4; $i++) {
        Set-Pose $i
        for ($j=0; $j -lt 180; $j++) { Animate-Pet ($j/30.0) }
        if ($pet.Source.PixelWidth -le 0) { throw 'Sprite load failed' }
    }
    Set-Pose 0
    $script:nextExpression=1000
    $script:blinkEnd=100
    Animate-Pet 99
    if (-not [Object]::ReferenceEquals($pet.Source,$script:blinkSprites[0])) { throw 'Blink failed' }
    $script:blinkEnd=0; $script:nextBlink=200
    Animate-Pet 100
    if (-not [Object]::ReferenceEquals($pet.Source,$script:sprites[0])) { throw 'Eye reopen failed' }
    $script:motion=$false
    Animate-Pet 101
    if ($pet.RenderTransform.Children[1].Angle -ne 0) { throw 'Reduced motion failed' }
    $script:motion=$true
    Set-Pose 3
    Play-Expression 0
    Animate-Pet 0.5
    if (-not [Object]::ReferenceEquals($pet.Source,$script:playfulSprites[3])) { throw 'Playful expression missing' }
    Set-Pose 2
    Play-Expression 1
    Animate-Pet 1.5
    if ([Object]::ReferenceEquals($pet.Source,$script:playfulSprites[2])) { throw 'Sleeping pet should not wink' }
    Set-Pose 1
    Start-PhoneDrop 0
    Animate-Pet 0.8
    if ($fallingPhone.Visibility -ne 'Visible') { throw 'Falling phone is missing' }
    Animate-Pet 1.2
    if (-not [Object]::ReferenceEquals($pet.Source,$script:dropSprites[2])) { throw 'Impact frame is missing' }
    Animate-Pet 2
    if (-not $script:dropSpoke) { throw 'Drop reaction is missing' }
    $pickupTimes=@(3.5,3.9,4.5,5.2)
    for ($i=0;$i -lt 4;$i++) {
        Animate-Pet $pickupTimes[$i]
        if (-not [Object]::ReferenceEquals($pet.Source,$script:pickupSprites[$i])) { throw 'Pickup hand sequence missing' }
        if ($fallingPhone.Visibility -ne 'Hidden') { throw 'Phone must stay in hand while being picked up' }
    }
    Animate-Pet 6
    if ($null -ne $script:dropStart -or $fallingPhone.Visibility -ne 'Hidden') { throw 'Drop scene did not recover' }
    Start-PhoneDrop 5
    $script:motion=$false
    Animate-Pet 5.8
    if ($null -ne $script:dropStart) { throw 'Reduced motion did not cancel drop' }
    $script:motion=$true
    for ($i=0; $i -lt 4; $i++) {
        Set-Pose $i
        React-ToPoke 200
        $contextPool=@('eatPoke','phonePoke','sleepPoke','gamePoke')[$i]
        if ($script:extraLines[$contextPool] -notcontains $words.Text) { throw 'Click dialogue must match the current activity' }
        Animate-Pet 200.5
        if (-not [Object]::ReferenceEquals($pet.Source,$script:lookSprites[$i])) { throw 'Poke gaze missing' }
        if ($pet.RenderTransform.Children[2].Y -ne 0 -or $pet.RenderTransform.Children[1].Angle -ne 0) { throw 'Poke should be still' }
        Animate-Pet 203
        if ([Object]::ReferenceEquals($pet.Source,$script:lookSprites[$i])) { throw 'Poke should return to activity' }
    }
    Set-Pose 0
    $savedRoamDeadline=$script:nextRoam; $savedDetailDeadline=$script:nextRest; $savedExpressionDeadline=$script:nextExpression
    Set-Pose 3
    if ($script:nextRoam -ne $savedRoamDeadline -or $script:nextRest -ne $savedDetailDeadline -or $script:nextExpression -ne $savedExpressionDeadline) { throw 'Activity changes must not postpone walking or details' }
    Start-Roam 300
    if ($null -eq $script:roam) { throw 'Roam failed to start' }
    $target=$script:roam.toX
    $travelSeconds=$script:roam.seconds
    Update-Roam 300.5
    if (-not [Object]::ReferenceEquals($pet.Source,$script:stretchSprite)) { throw 'Stretch missing' }
    Update-Roam (301.1+$travelSeconds/2)
    if ($window.Left -lt $area.Left -or $window.Left+$window.Width -gt $area.Right) { throw 'Walk left work area' }
    $previousDistance=-1
    for ($sample=0; $sample -le 100; $sample++) {
        $distance=Get-WalkDistance ($travelSeconds*$sample/100) ([Math]::Abs($target-$script:roam.fromX)) $travelSeconds
        if ($distance -lt $previousDistance -or $distance -lt 0) { throw 'Walk progress must be monotonic' }
        $previousDistance=$distance
    }
    foreach ($frame in $script:walkCycle) {
        if ($frame.Width -ne 627 -or $frame.Height -ne 627) { throw 'Walk frame alignment mismatch' }
    }
    Update-Roam (302+$travelSeconds)
    if ($null -ne $script:roam -or [Math]::Abs($window.Left-$target) -gt 1) { throw 'Walk did not settle' }
    Start-Roam 400
    Update-Roam 402.1
    $walkPauseX=$window.Left
    $pausedStride=$script:roam.frameIndex
    $pausedDirection=$script:roam.direction
    React-ToPoke 402.1
    Update-Roam 403.09
    if ($null -eq $script:roam -or $window.Left -ne $walkPauseX -or $script:extraLines.walkPoke -notcontains $words.Text) { throw 'Walking click must pause and answer' }
    if (-not [Object]::ReferenceEquals($pet.Source,$script:walkLookCycle[$pausedStride])) { throw 'Walking click must turn only the head in the current standing stride' }
    if ($pet.RenderTransform.Children[0].ScaleX -ne -$pausedDirection) { throw 'Head glance must preserve walking body direction' }
    Update-Roam 403.11
    if ($null -ne $script:roam.pausedAt) { throw 'Walking must resume after answering' }
    if ($script:walkCycle -notcontains $pet.Source -or $bubble.Visibility -ne 'Hidden') { throw 'Walking must resume immediately with no lingering speech' }
    if ([Math]::Abs($window.Left-$walkPauseX) -gt 4) { throw 'Resuming a walk must not jump ahead' }
    $resumeX=$window.Left
    Update-Roam 403.21
    if ([Math]::Abs($window.Left-$resumeX) -lt 2) { throw 'Walk must move again immediately after the one-second look' }
    Stop-Roam 406
    $window.Left=$area.Right-$window.Width-12
    Start-Roam 410 -Across
    if ([Math]::Abs($script:roam.toX-($area.Left+12)) -gt 1 -or -not $script:roam.crossing) { throw 'Cross-screen destination must reach opposite edge' }
    if ($script:roam.seconds -ge [Math]::Abs($script:roam.toX-$script:roam.fromX)/90+0.45) { throw 'Walking speed must be faster' }
    Stop-Roam 411
    $script:roamEnabled=$false
    Start-Roam 500
    if ($null -ne $script:roam) { throw 'Disabled roaming started' }
    for ($i=0; $i -lt 4; $i++) {
        Set-Pose $i
        $activityDeadline=$script:nextChange
        Start-Rest 600
        if ($null -eq $script:rest) { throw 'Rest action missing' }
        $detailDue=$script:nextRest
        if ($detailDue -lt 720 -or $detailDue -gt 840) { throw 'Small actions must recur within two to four minutes' }
        Update-Rest 601.2
        $expectedSource=if ($i -eq 3) { $script:rest.gameSource } else { $script:restSprites[@(5,3,1)[$i]] }
        if (-not [Object]::ReferenceEquals($pet.Source,$expectedSource)) { throw 'Rest pose incorrect' }
        Update-Rest (600+$script:rest.hold+1)
        if ($null -ne $script:rest -or $pet.Opacity -ne 1) { throw 'Rest action failed to finish' }
        if ($script:nextRest -ne $detailDue -or $script:mode -ne $i -or $script:nextChange -ne $activityDeadline) { throw 'Small motions must preserve the activity and not restart the detail interval' }
    }
    Start-Rest 700
    React-ToPoke 700.2
    if ($null -ne $script:rest -or $restBlend.Visibility -ne 'Hidden') { throw 'Poke must interrupt resting' }
    $script:dragging=$true; $script:pressed=$true
    $script:dragOriginTop=$window.Top
    Track-PetLift 800
    if ($script:lifted) { throw 'Horizontal drag should not wriggle' }
    $window.Top-=20
    Track-PetLift 800.2
    if (-not $script:lifted) { throw 'Upward drag should lift the pet' }
    Animate-Pet 800.5; Render-PetLift 800.5
    if ($groundShadow.Opacity -ne 0) { throw 'Lifted pet should have no ground shadow' }
    if ($script:liftCycle -notcontains $pet.Source) { throw 'Lift must use the eight-frame paddling cycle' }
    for ($frameIndex=0;$frameIndex -lt 8;$frameIndex++) {
        $rawBounds=$liftBounds[$frameIndex]; $raw=$liftFrames[$frameIndex]
        if ($rawBounds[0] -lt 4 -or $rawBounds[1] -lt 4 -or $rawBounds[2] -gt $raw.PixelWidth-5 -or $rawBounds[3] -gt $raw.PixelHeight-5) { throw 'Lift atlas crop cuts a limb or ear' }
        $visual=[Windows.Media.DrawingVisual]::new(); $ctx=$visual.RenderOpen()
        $ctx.DrawImage($script:liftCycle[$frameIndex],[Windows.Rect]::new(0,0,627,627)); $ctx.Close()
        $render=[Windows.Media.Imaging.RenderTargetBitmap]::new(627,627,96,96,[Windows.Media.PixelFormats]::Pbgra32); $render.Render($visual)
        $visible=Get-RestBounds $render
        if ($visible[3] -gt 601 -or $visible[0] -lt 12 -or $visible[2] -gt 615) { throw 'Lifted feet require safe drawing margins' }
    }
    $script:motion=$false
    Render-PetLift 800.6
    if (-not [Object]::ReferenceEquals($pet.Source,$script:liftCycle[0])) { throw 'Reduced lift motion must remain still' }
    $script:motion=$true
    Write-Output 'PASS: eight-frame scrunched-face lift cycle; uncropped source cells and full-foot rendering; reduced motion.'
    End-PetDrag 801
    if ($script:dragging -or $script:lifted -or $script:sulkEnd -le 801) { throw 'Release should settle into sulk' }
    Render-PetLift 801.5
    if (-not [Object]::ReferenceEquals($pet.Source,$script:liftSprites[3])) { throw 'Put-down pose missing' }
    $script:sulkEnd=0
    Set-Pose 0
    Start-BackTurn 900
    Animate-Pet 901; Update-BackTurn 901
    if (-not [Object]::ReferenceEquals($pet.Source,$script:backSprites[0])) { throw 'Back-facing idle missing' }
    React-ToPoke 902
    Animate-Pet 902.3; Update-BackTurn 902.3
    if (-not [Object]::ReferenceEquals($pet.Source,$script:backSprites[2]) -or $script:extraLines.backPoke -notcontains $words.Text) { throw 'Shoulder glance reaction missing' }
    Update-BackTurn 903.25
    if (-not [Object]::ReferenceEquals($pet.Source,$script:backSprites[3])) { throw 'Shoulder glance blink missing' }
    Update-BackTurn 905
    if (-not [Object]::ReferenceEquals($pet.Source,$script:backSprites[0])) { throw 'Pet must turn back after glance' }
    Start-Rest 905; Start-Roam 905
    if ($null -ne $script:rest -or $null -ne $script:roam) { throw 'Back-facing idle must block other actions' }
    Set-Pose 1
    if ($null -ne $script:backTurn) { throw 'Mode change must clear back-facing idle' }
    Write-Output 'PASS: back-facing idle, click glance, blink, return, and interruption.'
    Set-Pose 2
    $sleepDeadline=$script:nextChange
    if (($sleepDeadline-[DateTime]::Now).TotalSeconds -lt 119) { throw 'Sleep must last at least two minutes' }
    React-ToPoke 1000
    Start-Rest 1003
    Update-Rest 1005
    if ($script:mode -ne 2 -or $script:nextChange -ne $sleepDeadline) { throw 'Poke and repositioning must preserve sleep' }
    Stop-Rest 1100
    $script:roamEnabled=$true; $script:nextRoam=0; $script:nextBack=0; $script:quietUntil=0
    $SelfTest=$false
    try { Update-Roam 1101; Update-BackTurn 1101 } finally { $SelfTest=$true }
    if ($null -ne $script:roam -or $null -ne $script:backTurn) { throw 'Sleeping pet must not autonomously walk or turn away' }
    for ($sample=0;$sample -lt 30;$sample++) {
        Set-Pose 2
        Continue-Life
        if ($script:mode -eq 0 -or $script:mode -eq 3) { throw 'Sleep must ease into waking rest' }
    }
    Write-Output 'PASS: minute-scale sleep, sleep-preserving touch/repositioning, no sleep wandering, gentle waking transitions.'
    $script:pet.Source=$script:liftSprites[3]
    Say '휴. 바닥이 좋긴 하네.'
    Update-BubblePosition
    $bubbleGap=$script:bubbleHeadCache[$pet.Source]-[Windows.Controls.Canvas]::GetTop($bubble)-$bubble.DesiredSize.Height
    if ($script:bubbleHeadCache[$pet.Source] -lt 95 -or [Math]::Abs($bubbleGap-6) -gt 0.5) { throw 'Put-down speech must stay close to the actual head' }
    Write-Output 'PASS: speech bubble follows the main silhouette and ignores isolated atlas marks.'
    Set-Pose 0
    $beforeLying=$pet.Source
    Set-Pose 2
    Start-PostureTransition 0 2 1200 $beforeLying
    Render-PostureTransition 1200.3
    if (-not [Object]::ReferenceEquals($pet.Source,$script:transitionSprites[1])) { throw 'Lying down must start by supporting weight with a hand' }
    Start-Rest 1201; Start-Roam 1201; Start-BackTurn 1201
    if ($null -ne $script:rest -or $null -ne $script:roam -or $null -ne $script:backTurn) { throw 'Other actions must wait for the posture transition' }
    $endTransition=1200+$script:poseTransition.duration+0.1
    Animate-Pet $endTransition; Render-PostureTransition $endTransition
    if ($null -ne $script:poseTransition -or $script:mode -ne 2) { throw 'Posture transition must finish in sleeping mode' }
    $waking=@(Get-PostureRoute 2 0)
    if ($waking[0] -ne 11 -or $waking[-1] -ne 0 -or $waking -contains 6) { throw 'Getting up must reverse the body movement without inventing a phone' }
    Start-PostureTransition 2 1 1300 $pet.Source
    $script:motion=$false; Render-PostureTransition 1300.3
    if ($null -ne $script:poseTransition) { throw 'Reduced motion must skip posture transition' }
    $script:motion=$true
    Write-Output 'PASS: hand-supported lying down, getting up, phone/sleep transitions, action exclusion, and reduced motion.'
    Say '테스트'
    $window.Measure([Windows.Size]::new(232,270))
    $window.Arrange([Windows.Rect]::new(0,0,232,270))
    $window.UpdateLayout()
    $window.Left=-10000
    $window.ShowActivated=$false
    $window.Show()
    . (Join-Path $PSScriptRoot 'Pomodoro.Tests.ps1')
    Invoke-PomodoroSelfTest
    $script:classEnd=[DateTime]::Now.AddMinutes(20)
    $savedClassEnd=$script:classEnd
    $savedTop=$window.Top
    Toggle-PetVisibility
    if ($window.IsVisible -or $script:clock.IsRunning) { throw 'Hide must pause visual activity' }
    if ($script:timer.IsEnabled -or -not $script:classTimer.IsEnabled) { throw 'Hidden pet must stop animation polling and retain the class deadline' }
    Toggle-PetVisibility
    if (-not $window.IsVisible -or -not $script:clock.IsRunning) { throw 'Show must resume visual activity' }
    if ($window.Left -ne -10000 -or $window.Top -ne $savedTop -or $script:classEnd -ne $savedClassEnd) { throw 'Toggle changed position or class timer' }
    if (-not $script:timer.IsEnabled) { throw 'Show must restart the animation timer' }
    Write-Output 'PASS: hide/show retains position and class timer; hidden animation polling stops.'
    Write-Output ('PASS: 78 sprites; upward lift/wriggle/release; four-stage hand pickup; rest/eat/phone poses and interruption; aligned eight-frame gait; distance easing; expressions; phone drop; quiet poke; roam/stretch/bounds/settle/cancel/disable; WPF layout; {0} menu entries.' -f $menu.Items.Count)
    . (Join-Path $PSScriptRoot 'Chaos.Tests.ps1')
    Invoke-ChaosSelfTest
    $window.Close()
    exit 0
}
Say-Random 'hello'
if ($null -ne $script:toggleEvent) {
    $context=[Windows.Threading.DispatcherSynchronizationContext]::new($window.Dispatcher)
    $script:visibilityWatcher=[KikkiEventWatcher]::new($script:toggleEvent,$context,[Action]{ Toggle-PetVisibility })
}
$window.Add_Loaded({ Sync-PetTimers })
$script:app=[Windows.Application]::new()
$script:app.ShutdownMode=[Windows.ShutdownMode]::OnMainWindowClose
try { [void]$script:app.Run($window) }
finally {
    if ($null -ne $script:visibilityWatcher) { $script:visibilityWatcher.Dispose() }
    if ($null -ne $script:toggleEvent) { $script:toggleEvent.Dispose() }
    if ($null -ne $script:petMutex) { $script:petMutex.ReleaseMutex(); $script:petMutex.Dispose() }
}
