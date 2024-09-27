package main

import (
	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
	"image/color"
)

type myTheme struct {
}

func (m myTheme) Font(style fyne.TextStyle) fyne.Resource {
	//TODO implement me
	return theme.DefaultTheme().Font(style)
}

func (m myTheme) Icon(name fyne.ThemeIconName) fyne.Resource {
	//TODO implement me
	return theme.DefaultTheme().Icon(name)
}

func (m myTheme) Size(name fyne.ThemeSizeName) float32 {
	//TODO implement me
	return theme.DefaultTheme().Size(name)
}

func (m myTheme) Color(name fyne.ThemeColorName, variant fyne.ThemeVariant) color.Color {
	if name == theme.ColorNamePrimary {
		return color.RGBA{
			R: 124,
			G: 160,
			B: 113,
			A: 255,
		}

		// #7ca071
	}

	return theme.DefaultTheme().Color(name, variant)
}

var _ fyne.Theme = (*myTheme)(nil)

func main() {
	myApp := app.New()
	myApp.Settings().SetTheme(&myTheme{})

	myWindow := myApp.NewWindow("BoxWallet")
	myWindow.Resize(fyne.NewSize(640, 480))

	logo := canvas.NewImageFromResource(resourceBwlogoPng)
	logo.SetMinSize(fyne.NewSize(75, 75))
	//logo.Resize(fyne.NewSize(75, 75))
	diviLogo := canvas.NewImageFromResource(resourceDivilogoPng)
	//boxWallet := canvas.NewText(" BoxWallet", color.White)
	//boxWallet.TextStyle = fyne.TextStyle{Bold: true}
	boxWallet := widget.NewRichTextFromMarkdown(" ## BoxWallet")
	version := canvas.NewText("  v0.0.2 ALPHA", color.White)
	//left := canvas.NewText("left", color.White)
	//middle := canvas.NewText("content", color.White)
	//bottom := canvas.NewText("bottom", color.White)
	//spaceLabel := widget.NewLabel("SPace")
	blankLine := canvas.NewLine(color.RGBA{R: 0, G: 0, B: 0, A: 0})
	boxWalletCombo := container.NewVBox(blankLine, boxWallet, version)
	topPanelH := container.NewHBox(blankLine, logo, boxWalletCombo)
	topPanel := container.NewVBox(blankLine, topPanelH, blankLine, blankLine, blankLine)
	homeStr1 := widget.NewRichTextFromMarkdown("   # Welcome to BoxWallet")
	//homeStr2 := widget.NewSeparator()
	homeStr3 := widget.NewLabel("BoxWallet is a multi-coin wallet, that can get your coin-of-choice up and running fast and securely staking with just a few clicks..")
	homeStr3.Wrapping = fyne.TextWrapWord
	homeStr4 := widget.NewLabel("Please choose your coin-of-choice on the left, to get started")
	//homeContent := canvas.NewText(homeStr.String(), color.White)
	homeContent := container.NewVBox(homeStr1, homeStr3, homeStr4)
	leftPanel := container.NewAppTabs(
		container.NewTabItemWithIcon("Home", theme.HomeIcon(), homeContent),
		container.NewTabItemWithIcon("DIVI", diviLogo.Resource, getDiviContent()),
	)
	leftPanel.SetTabLocation(container.TabLocationLeading)
	//content := container.NewBorder(topPanel, bottom, leftPanel, nil, middle)
	content := container.NewBorder(topPanel, nil, nil, nil, leftPanel)
	myWindow.SetContent(content)
	myWindow.ShowAndRun()

}

func homeClicked() {

}

func getDiviContent() *fyne.Container {
	blankLine := canvas.NewLine(color.RGBA{R: 0, G: 0, B: 0, A: 0})
	diviLogo := canvas.NewImageFromResource(resourceDivilogoPng)
	diviLogo.SetMinSize(fyne.NewSize(100, 100))

	diviTitle := widget.NewRichTextFromMarkdown("   # Divi")
	diviVersion := widget.NewRichTextFromMarkdown("v3.0.0.0")
	//diviVersion := widget.NewLabel("v3.0.0.0")
	diviCombo := container.NewVBox(diviTitle, diviVersion)

	topSection := container.NewHBox(blankLine, blankLine, diviLogo, diviCombo)

	diviSubTitle := widget.NewRichTextFromMarkdown("  ## Crypto Made Easy")
	diviDesc := widget.NewLabel("The foundation for a truly decentralized future. Our rapidly changing world requires flexible financial products. Through our innovative technology, we’re building the future of finance.")
	diviDesc.Wrapping = fyne.TextWrapWord

	return container.NewVBox(topSection, diviSubTitle, diviDesc)
}
