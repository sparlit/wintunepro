using System;
using System.Threading.Tasks;
using System.Windows;

namespace WinTunePro
{
    public partial class MainWindow : Window
    {
        private string AppRoot;
        public MainWindow()
        {
            InitializeComponent();
            AppRoot = AppDomain.CurrentDomain.BaseDirectory;
        }

        private async void BtnScan_Click(object sender, RoutedEventArgs e)
        {
            AppendOutput("Starting scan prototype in TestMode...");
            var res = await Task.Run(() => RunPowerShellScript("Invoke-CleaningScan", true));
            AppendOutput(res);
        }

        private async void BtnClean_Click(object sender, RoutedEventArgs e)
        {
            AppendOutput("Starting cleaning prototype in TestMode...");
            var res = await Task.Run(() => RunPowerShellScript("Invoke-Cleaning", true));
            AppendOutput(res);
        }

        private async void BtnOptimize_Click(object sender, RoutedEventArgs e)
        {
            AppendOutput("Starting optimization prototype in TestMode...");
            var res = await Task.Run(() => RunPowerShellScript("Invoke-Optimization", true));
            AppendOutput(res);
        }

        private string RunPowerShellScript(string command, bool testMode)
        {
            try
            {
                return $"[PROTOTYPE] NativeBuild currently simulates the canonical PowerShell workflow. Planned command: {command} (TestMode={testMode})";
            }
            catch (Exception ex)
            {
                return ex.ToString();
            }
        }

        private void AppendOutput(string text)
        {
            Dispatcher.Invoke(() =>
            {
                Output.AppendText(text + Environment.NewLine + Environment.NewLine);
                Output.ScrollToEnd();
            });
        }
    }
}
