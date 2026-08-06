using Microsoft.Windows.ApplicationModel.Resources;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System.Text.Json;
using Windows.ApplicationModel.DataTransfer;
using Windows.System;
using System8Dashboard.Core.Models;
using System8Dashboard.Core.Services;
using System8Dashboard.ViewModels;

namespace System8Dashboard;

public sealed partial class MainWindow : Window
{
    private readonly ResourceLoader _resources = new();
    private readonly PimEligibilityService _pimEligibilityService;
    private readonly string _settingsPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "System8",
        "dashboard",
        "settings.json");
    private string _selectedTheme = "Default";

    public MainWindow(MainViewModel viewModel, PimEligibilityService pimEligibilityService)
    {
        ViewModel = viewModel;
        _pimEligibilityService = pimEligibilityService;
        InitializeComponent();
        ExtendsContentIntoTitleBar = true;
        SetTitleBar(AppTitleBar);
        AppWindow.SetIcon("Assets/AppIcon.ico");
        AppWindow.Resize(new Windows.Graphics.SizeInt32(1280, 820));
        Activated += OnActivated;
    }

    public MainViewModel ViewModel { get; }

    private void OnActivated(object sender, WindowActivatedEventArgs args)
    {
        Activated -= OnActivated;
        LoadSettings();
        ViewModel.Refresh();
        ShellNavigation.SelectedItem = ShellNavigation.MenuItems[0];
    }

    private async void OnRunClicked(object sender, RoutedEventArgs e)
    {
        RunButton.IsEnabled = false;
        try { await ViewModel.RunSelectedAsync(); }
        finally { RunButton.IsEnabled = true; }
    }

    private void OnRefreshClicked(object sender, RoutedEventArgs e) => ViewModel.Refresh();

    private async void OnInstallClicked(object sender, RoutedEventArgs e)
    {
        string installer = Path.Combine(AppContext.BaseDirectory, "Scripts", "install-user.ps1");
        InstallButton.IsEnabled = false;
        try { await ViewModel.InstallSelectedAsync(installer); }
        finally { InstallButton.IsEnabled = true; }
    }

    private async void OnOpenEvidenceClicked(object sender, RoutedEventArgs e)
    {
        if (ViewModel.LastRun is null || !Directory.Exists(ViewModel.LastRun.OutputPath)) return;
        await Launcher.LaunchFolderPathAsync(ViewModel.LastRun.OutputPath);
    }

    private async void OnRequestAccessClicked(object sender, RoutedEventArgs e)
    {
        SaveSettings();
        AccessRequestDraft? draft = ViewModel.CreateAccessRequest();
        if (draft is null) return;
        await Launcher.LaunchUriAsync(new Uri(draft.MailtoUri));
    }

    private async void OnCheckPimClicked(object sender, RoutedEventArgs e)
    {
        AccessRequestDraft? draft = ViewModel.CreateAccessRequest();
        if (draft is null) return;
        DataPackage package = new();
        package.SetText(draft.Body);
        Clipboard.SetContent(package);
        ViewModel.Status = _resources.GetString("StatusCheckingPim");
        PimEligibilityResult eligibility = await _pimEligibilityService.CheckAsync(
            Path.Combine(AppContext.BaseDirectory, "Scripts", "check-pim.ps1"),
            draft.SuggestedRoles);
        if (!eligibility.HasMatch)
        {
            ViewModel.Status = string.Format(System.Globalization.CultureInfo.CurrentCulture, _resources.GetString("StatusPimFallbackFormat"), eligibility.Message);
            await Launcher.LaunchUriAsync(new Uri(draft.MailtoUri));
            return;
        }

        ViewModel.Status = string.Format(System.Globalization.CultureInfo.CurrentCulture, _resources.GetString("StatusPimFoundFormat"), string.Join(", ", eligibility.EligibleRoles));
        ContentDialog dialog = new()
        {
            XamlRoot = Content.XamlRoot,
            Title = _resources.GetString("PimDialogTitle"),
            Content = string.Format(System.Globalization.CultureInfo.CurrentCulture, _resources.GetString("PimDialogContentFormat"), string.Join(", ", eligibility.EligibleRoles)),
            PrimaryButtonText = _resources.GetString("PimDialogPrimary"),
            CloseButtonText = _resources.GetString("PimDialogClose"),
            DefaultButton = ContentDialogButton.Primary,
        };
        if (await dialog.ShowAsync() == ContentDialogResult.Primary)
        {
            await Launcher.LaunchUriAsync(new Uri("https://entra.microsoft.com/#view/Microsoft_Azure_PIMCommon/ActivationMenuBlade/~/aadroles"));
        }
    }

    private async void OnSupportClicked(object sender, RoutedEventArgs e) => await Launcher.LaunchUriAsync(new Uri("https://github.com/enkayz/system8/issues/new?template=support.yml"));

    private async void OnNavigationSelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItemContainer?.Tag is not string tag) return;
        if (tag == "support") { await Launcher.LaunchUriAsync(new Uri("https://github.com/enkayz/system8/issues/new?template=support.yml")); return; }
        OverviewPage.Visibility = tag == "overview" ? Visibility.Visible : Visibility.Collapsed;
        ToolsPage.Visibility = tag == "tools" ? Visibility.Visible : Visibility.Collapsed;
        RequestsPage.Visibility = tag == "requests" ? Visibility.Visible : Visibility.Collapsed;
        SettingsPage.Visibility = tag == "settings" ? Visibility.Visible : Visibility.Collapsed;
    }

    private void OnThemeChanged(object sender, SelectionChangedEventArgs e)
    {
        if (Content is not FrameworkElement root || ThemeSelector.SelectedItem is not ComboBoxItem item || item.Tag is not string theme) return;
        root.RequestedTheme = theme switch { "Light" => ElementTheme.Light, "Dark" => ElementTheme.Dark, _ => ElementTheme.Default };
        _selectedTheme = theme;
        SaveSettings();
    }

    private void LoadSettings()
    {
        DashboardSettings settings = File.Exists(_settingsPath)
            ? JsonSerializer.Deserialize<DashboardSettings>(File.ReadAllText(_settingsPath)) ?? new()
            : new();
        ViewModel.AdministratorEmail = settings.AdministratorEmail;
        _selectedTheme = settings.Theme;
        ThemeSelector.SelectedIndex = _selectedTheme == "Light" ? 1 : _selectedTheme == "Dark" ? 2 : 0;
    }

    private void SaveSettings()
    {
        Directory.CreateDirectory(Path.GetDirectoryName(_settingsPath)!);
        DashboardSettings settings = new(ViewModel.AdministratorEmail, _selectedTheme);
        File.WriteAllText(_settingsPath, JsonSerializer.Serialize(settings));
    }

    private sealed record DashboardSettings(string AdministratorEmail = "", string Theme = "Default");
}
