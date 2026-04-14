using System;
using System.IO;
using System.Windows;

namespace WinTunePro
{
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            var main = new MainWindow();
            main.Show();
        }
    }
}
