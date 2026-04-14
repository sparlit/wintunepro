# WinTune Pro - Main Window UI Module
# PowerShell 5.1+ Compatible
# Uses ASCII-only characters to avoid XML parsing issues

function global:Initialize-MainWindow {
    # Load required assemblies
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Drawing

    # XAML with ASCII-only characters
    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WinTune Pro v2.0" Height="850" Width="1400"
        MinWidth="900" MinHeight="650"
        SizeToContent="Manual"
        WindowStartupLocation="CenterScreen"
        Background="#F5F7FA"
        Foreground="#111827"
        WindowStyle="None"
        AllowsTransparency="True"
        ResizeMode="CanResizeWithGrip"
        FontFamily="Segoe UI">

    <Window.Resources>
        <SolidColorBrush x:Key="WindowBg" Color="#F5F7FA"/>
        <SolidColorBrush x:Key="SurfaceBg" Color="#FFFFFF"/>
        <SolidColorBrush x:Key="SurfaceBg2" Color="#F0F2F5"/>
        <SolidColorBrush x:Key="SurfaceHover" Color="#E8EAF0"/>
        <SolidColorBrush x:Key="PrimaryColor" Color="#2563EB"/>
        <SolidColorBrush x:Key="PrimaryHover" Color="#1D4ED8"/>
        <SolidColorBrush x:Key="SecondaryColor" Color="#0891B2"/>
        <SolidColorBrush x:Key="AccentColor" Color="#7C3AED"/>
        <SolidColorBrush x:Key="SuccessColor" Color="#16A34A"/>
        <SolidColorBrush x:Key="WarningColor" Color="#D97706"/>
        <SolidColorBrush x:Key="DangerColor" Color="#DC2626"/>
        <SolidColorBrush x:Key="InfoColor" Color="#2563EB"/>
        <SolidColorBrush x:Key="TextPrimary" Color="#111827"/>
        <SolidColorBrush x:Key="TextSecondary" Color="#4B5563"/>
        <SolidColorBrush x:Key="TextMuted" Color="#9CA3AF"/>
        <SolidColorBrush x:Key="BorderBrush" Color="#E5E7EB"/>

        <Style x:Key="MainTabItem" TargetType="TabItem">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Grid Name="Panel" Margin="2,0,2,0">
                            <Border Name="Border" Background="Transparent" BorderThickness="0,0,0,3"
BorderBrush="Transparent" Padding="15,10" CornerRadius="5,5,0,0">
                                <ContentPresenter x:Name="ContentSite" VerticalAlignment="Center"
HorizontalAlignment="Center" ContentSource="Header"/>
                            </Border>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Border" Property="BorderBrush" Value="{StaticResource PrimaryColor}"/>
                                <Setter TargetName="Border" Property="Background" Value="{StaticResource SurfaceBg2}"/>
                                <Setter Property="Foreground" Value="{StaticResource PrimaryColor}"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="False">
                                <Setter Property="Foreground" Value="{StaticResource TextSecondary}"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="{StaticResource SurfaceHover}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Setter Property="FontSize" Value="14"/>
        </Style>

        <Style x:Key="ModernButton" TargetType="Button">
            <Setter Property="Background" Value="{StaticResource PrimaryColor}"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Padding" Value="20,12"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="{StaticResource PrimaryHover}"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Opacity" Value="0.5"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource ModernButton}">
            <Setter Property="Background" Value="{StaticResource SurfaceBg2}"/>
            <Setter Property="Foreground" Value="{StaticResource TextPrimary}"/>
            <Setter Property="BorderBrush" Value="{StaticResource BorderBrush}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="{StaticResource SurfaceHover}"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource ModernButton}">
            <Setter Property="Background" Value="{StaticResource DangerColor}"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#FF8566"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="SuccessButton" TargetType="Button" BasedOn="{StaticResource ModernButton}">
            <Setter Property="Background" Value="{StaticResource SuccessColor}"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#00D9A4"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="Card" TargetType="Border">
            <Setter Property="Background" Value="{StaticResource SurfaceBg}"/>
            <Setter Property="CornerRadius" Value="12"/>
            <Setter Property="Padding" Value="20"/>
            <Setter Property="BorderBrush" Value="{StaticResource BorderBrush}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Effect">
                <Setter.Value>
                    <DropShadowEffect BlurRadius="8" ShadowDepth="1" Opacity="0.08" Color="#000000"/>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="StatCard" TargetType="Border" BasedOn="{StaticResource Card}">
            <Setter Property="Padding" Value="15"/>
        </Style>

        <Style x:Key="ModernCheckBox" TargetType="CheckBox">
            <Setter Property="Foreground" Value="{StaticResource TextPrimary}"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Margin" Value="0,6"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <Grid Background="Transparent">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="20"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Border x:Name="CheckBoxBorder" Width="18" Height="18" CornerRadius="4"
                                    Background="{StaticResource SurfaceBg2}" BorderBrush="{StaticResource BorderBrush}" BorderThickness="2">
                                <Path x:Name="CheckMark" Data="M 0 5 L 5 10 L 12 0" Stroke="{StaticResource PrimaryColor}" StrokeThickness="2"
                                      Stretch="None" Visibility="Collapsed" Margin="3"/>
                            </Border>
                            <ContentPresenter Grid.Column="1" Margin="8,0,0,0" VerticalAlignment="Center"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="CheckBoxBorder" Property="BorderBrush" Value="{StaticResource PrimaryColor}"/>
                                <Setter TargetName="CheckMark" Property="Visibility" Value="Visible"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="CheckBoxBorder" Property="Background" Value="{StaticResource SurfaceHover}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="ModernProgressBar" TargetType="ProgressBar">
            <Setter Property="Height" Value="8"/>
            <Setter Property="Background" Value="{StaticResource SurfaceBg2}"/>
            <Setter Property="Foreground" Value="{StaticResource PrimaryColor}"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ProgressBar">
                        <Grid>
                            <Border Background="{TemplateBinding Background}" CornerRadius="4"/>
                            <Border x:Name="PART_Indicator" Background="{TemplateBinding Foreground}" CornerRadius="4" HorizontalAlignment="Left"/>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="ModernScrollViewer" TargetType="ScrollViewer">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="VerticalScrollBarVisibility" Value="Auto"/>
            <Setter Property="HorizontalScrollBarVisibility" Value="Disabled"/>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="50"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="35"/>
        </Grid.RowDefinitions>

        <!-- Title Bar -->
        <Border Grid.Row="0" Background="{StaticResource SurfaceBg}" CornerRadius="10,10,0,0" BorderBrush="{StaticResource BorderBrush}" BorderThickness="0,0,0,1">
            <Grid>
                <StackPanel Orientation="Horizontal" Margin="20,0">
                    <Border Background="{StaticResource PrimaryColor}" CornerRadius="8" Padding="8,4" Margin="0,0,12,0">
                        <TextBlock Text="WT" FontSize="16" FontWeight="Bold" Foreground="White"/>
                    </Border>
                    <TextBlock Text="WinTune Pro" FontSize="20" FontWeight="Bold" VerticalAlignment="Center" Foreground="{StaticResource TextPrimary}"/>
                    <TextBlock Text="v2.0" FontSize="12" VerticalAlignment="Center" Margin="10,3,0,0" Foreground="{StaticResource TextMuted}"/>
                </StackPanel>

                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                    <Border x:Name="TestModeBadge" Background="#F59E0B" CornerRadius="4" Padding="12,4" Margin="0,0,10,0" VerticalAlignment="Center" Visibility="Collapsed">
                        <TextBlock x:Name="TestModeText" Text="[SIMULATION]" FontSize="12" FontWeight="SemiBold" Foreground="White"/>
                    </Border>
                    <Border x:Name="AdminBadge" Background="{StaticResource SuccessColor}" CornerRadius="4" Padding="12,4" Margin="0,0,10,0" VerticalAlignment="Center">
                        <TextBlock x:Name="AdminText" Text="[ADMIN]" FontSize="12" FontWeight="SemiBold" Foreground="White"/>
                    </Border>

                    <Button x:Name="MinimizeBtn" Content="_" Width="45" Height="50" Style="{x:Null}" Background="Transparent" Foreground="{StaticResource TextSecondary}" FontSize="18" BorderThickness="0"/>
                    <Button x:Name="MaximizeBtn" Content="[ ]" Width="45" Height="50" Style="{x:Null}" Background="Transparent" Foreground="{StaticResource TextSecondary}" FontSize="16" BorderThickness="0"/>
                    <Button x:Name="CloseBtn" Content="X" Width="45" Height="50" Style="{x:Null}" Background="{StaticResource DangerColor}" Foreground="White" FontSize="14" BorderThickness="0"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- Main Content Area with Tabs -->
        <Grid Grid.Row="1" Margin="10,0,10,10">
            <TabControl x:Name="MainTabControl" Background="Transparent" BorderThickness="0" Padding="0">
                <TabControl.Template>
                    <ControlTemplate TargetType="TabControl">
                        <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <TabPanel Grid.Row="0" IsItemsHost="True" Background="{StaticResource SurfaceBg}" Margin="0,0,0,5"/>
                    <Border Grid.Row="1" Background="{StaticResource SurfaceBg}" CornerRadius="10">
                        <ScrollViewer x:Name="TabContentScroll" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="16">
                            <Border Background="{StaticResource SurfaceBg}" CornerRadius="10" Padding="16" BorderBrush="{StaticResource BorderBrush}" BorderThickness="1">
                                <ContentPresenter ContentSource="SelectedContent"/>
                            </Border>
                        </ScrollViewer>
                    </Border>
                        </Grid>
                    </ControlTemplate>
                </TabControl.Template>

                <!-- DASHBOARD TAB -->
                <TabItem Header="Dashboard" Style="{StaticResource MainTabItem}">
                    <ScrollViewer Style="{StaticResource ModernScrollViewer}" Padding="20">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <!-- Welcome -->
                            <Border Grid.Row="0" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <Grid>
                                    <StackPanel>
                                        <TextBlock Text="Welcome to WinTune Pro" FontSize="28" FontWeight="Bold" Foreground="{StaticResource TextPrimary}"/>
                                        <TextBlock Text="Your comprehensive Windows optimization toolkit" FontSize="14" Foreground="{StaticResource TextSecondary}" Margin="0,5,0,0"/>
                                    </StackPanel>
                                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                                        <Button x:Name="QuickOptimizeBtn" Content="Quick Optimize" Style="{StaticResource SuccessButton}" Margin="0,0,10,0" Width="150"/>
                                        <Button x:Name="MasterCleanBtn" Content="Master Clean All" Style="{StaticResource ModernButton}" Width="160"/>
                                    </StackPanel>
                                </Grid>
                            </Border>

                            <!-- Automation Panel -->
                            <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0">
                                        <TextBlock Text="Automation" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                        <StackPanel Orientation="Horizontal">
                                            <Button x:Name="RunFullAutomateBtn" Content="Run Full Automation" Style="{StaticResource SuccessButton}" Margin="0,0,10,0" Width="170"/>
                                            <Button x:Name="StartWatchdogBtn" Content="Start Watchdog" Style="{StaticResource ModernButton}" Margin="0,0,10,0" Width="140"/>
                                            <TextBlock Text="Profile:" VerticalAlignment="Center" Foreground="{StaticResource TextSecondary}" Margin="0,0,8,0"/>
                                            <ComboBox x:Name="ProfileCombo" Width="140" Height="28" Background="{StaticResource SurfaceBg2}" Foreground="{StaticResource TextPrimary}" BorderBrush="{StaticResource BorderBrush}">
                                                <ComboBoxItem Content="Gaming" IsSelected="True"/>
                                                <ComboBoxItem Content="Office"/>
                                                <ComboBoxItem Content="Multimedia"/>
                                                <ComboBoxItem Content="Developer"/>
                                                <ComboBoxItem Content="Privacy"/>
                                                <ComboBoxItem Content="Performance"/>
                                                <ComboBoxItem Content="Balanced"/>
                                                <ComboBoxItem Content="Battery"/>
                                            </ComboBox>
                                        </StackPanel>
                                    </StackPanel>
                                    <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                        <TextBlock x:Name="AutomationStatusText" Text="Idle" FontSize="13" Foreground="{StaticResource TextMuted}"/>
                                    </StackPanel>
                                </Grid>
                            </Border>

                            <!-- Health Score -->
                            <Grid Grid.Row="2" Margin="0,0,0,15">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="2*"/>
                                    <ColumnDefinition Width="3*"/>
                                </Grid.ColumnDefinitions>

                                <Border Grid.Column="0" Style="{StaticResource Card}" Margin="0,0,10,0">
                                    <Grid>
                                        <Grid.RowDefinitions>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="*"/>
                                            <RowDefinition Height="Auto"/>
                                        </Grid.RowDefinitions>
                                        <TextBlock Grid.Row="0" Text="System Health Score" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                        <Viewbox Grid.Row="1" Width="150" Height="150">
                                            <Grid>
                                                <Ellipse Width="140" Height="140" Stroke="{StaticResource SurfaceBg2}" StrokeThickness="12"/>
                                                <Ellipse x:Name="HealthCircle" Width="140" Height="140" Stroke="{StaticResource SuccessColor}" StrokeThickness="12" StrokeDashArray="100 440" StrokeDashCap="Round" RenderTransformOrigin="0.5,0.5">
                                                    <Ellipse.RenderTransform>
                                                        <RotateTransform Angle="-90"/>
                                                    </Ellipse.RenderTransform>
                                                </Ellipse>
                                                <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                                                    <TextBlock x:Name="HealthScoreText" Text="85" FontSize="42" FontWeight="Bold" Foreground="{StaticResource TextPrimary}" HorizontalAlignment="Center"/>
                                                    <TextBlock Text="/100" FontSize="14" Foreground="{StaticResource TextSecondary}" HorizontalAlignment="Center"/>
                                                </StackPanel>
                                            </Grid>
                                        </Viewbox>
                                        <TextBlock x:Name="HealthRatingText" Grid.Row="2" Text="Excellent" FontSize="18" FontWeight="SemiBold" Foreground="{StaticResource SuccessColor}" HorizontalAlignment="Center" Margin="0,10,0,0"/>
                                    </Grid>
                                </Border>

                                <UniformGrid Grid.Column="1" Columns="2" Rows="2">
                                    <Border Style="{StaticResource StatCard}" Margin="5">
                                        <Grid>
                                            <Grid.RowDefinitions>
                                                <RowDefinition Height="Auto"/>
                                                <RowDefinition Height="Auto"/>
                                            </Grid.RowDefinitions>
                                            <TextBlock Grid.Row="0" Text="[DISK]" FontSize="16" Foreground="{StaticResource InfoColor}"/>
                                            <TextBlock Grid.Row="1" x:Name="StatRecoverable" Text="0 GB" FontSize="24" FontWeight="Bold" Foreground="{StaticResource TextPrimary}" Margin="0,8,0,0"/>
                                            <TextBlock Grid.Row="1" Text="Recoverable Space" FontSize="12" Foreground="{StaticResource TextSecondary}" Margin="0,40,0,0"/>
                                        </Grid>
                                    </Border>
                                    <Border Style="{StaticResource StatCard}" Margin="5">
                                        <Grid>
                                            <Grid.RowDefinitions>
                                                <RowDefinition Height="Auto"/>
                                                <RowDefinition Height="Auto"/>
                                            </Grid.RowDefinitions>
                                            <TextBlock Grid.Row="0" Text="[TEMP]" FontSize="16" Foreground="{StaticResource WarningColor}"/>
                                            <TextBlock Grid.Row="1" x:Name="StatTempFiles" Text="0 files" FontSize="24" FontWeight="Bold" Foreground="{StaticResource TextPrimary}" Margin="0,8,0,0"/>
                                            <TextBlock Grid.Row="1" Text="Temporary Files" FontSize="12" Foreground="{StaticResource TextSecondary}" Margin="0,40,0,0"/>
                                        </Grid>
                                    </Border>
                                    <Border Style="{StaticResource StatCard}" Margin="5">
                                        <Grid>
                                            <Grid.RowDefinitions>
                                                <RowDefinition Height="Auto"/>
                                                <RowDefinition Height="Auto"/>
                                            </Grid.RowDefinitions>
                                            <TextBlock Grid.Row="0" Text="[SVC]" FontSize="16" Foreground="{StaticResource PrimaryColor}"/>
                                            <TextBlock Grid.Row="1" x:Name="StatServices" Text="0" FontSize="24" FontWeight="Bold" Foreground="{StaticResource TextPrimary}" Margin="0,8,0,0"/>
                                            <TextBlock Grid.Row="1" Text="Running Services" FontSize="12" Foreground="{StaticResource TextSecondary}" Margin="0,40,0,0"/>
                                        </Grid>
                                    </Border>
                                    <Border Style="{StaticResource StatCard}" Margin="5">
                                        <Grid>
                                            <Grid.RowDefinitions>
                                                <RowDefinition Height="Auto"/>
                                                <RowDefinition Height="Auto"/>
                                            </Grid.RowDefinitions>
                                            <TextBlock Grid.Row="0" Text="[START]" FontSize="16" Foreground="{StaticResource AccentColor}"/>
                                            <TextBlock Grid.Row="1" x:Name="StatStartup" Text="0" FontSize="24" FontWeight="Bold" Foreground="{StaticResource TextPrimary}" Margin="0,8,0,0"/>
                                            <TextBlock Grid.Row="1" Text="Startup Items" FontSize="12" Foreground="{StaticResource TextSecondary}" Margin="0,40,0,0"/>
                                        </Grid>
                                    </Border>
                                </UniformGrid>
                            </Grid>

                            <!-- Disk Usage -->
                            <Border Grid.Row="2" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                    </Grid.RowDefinitions>
                                    <TextBlock Grid.Row="0" Text="Disk Usage" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,15"/>
                                    <StackPanel Grid.Row="1" x:Name="DiskUsagePanel"/>
                                </Grid>
                            </Border>

                            <!-- Memory & CPU -->
                            <Grid Grid.Row="3" Margin="0,0,0,15">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>

                                <Border Grid.Column="0" Style="{StaticResource Card}" Margin="0,0,8,0">
                                    <Grid>
                                        <Grid.RowDefinitions>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="*"/>
                                        </Grid.RowDefinitions>
                                        <TextBlock Grid.Row="0" Text="Memory Usage" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}"/>
                                        <TextBlock Grid.Row="1" x:Name="MemoryPercent" Text="0%" FontSize="24" FontWeight="Bold" Foreground="{StaticResource PrimaryColor}" Margin="0,5,0,10"/>
                                        <Grid Grid.Row="2">
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="Auto"/>
                                                <ColumnDefinition Width="*"/>
                                            </Grid.ColumnDefinitions>
                                            <Border Grid.Column="0" Width="20" Height="80" CornerRadius="5" Background="{StaticResource SurfaceBg2}" Margin="0,0,15,0">
                                                <Border x:Name="MemoryBar" Background="{StaticResource PrimaryColor}" CornerRadius="5" VerticalAlignment="Bottom" Height="0"/>
                                            </Border>
                                            <StackPanel Grid.Column="1">
                                                <Grid>
                                                    <TextBlock Text="Total:" FontSize="12" Foreground="{StaticResource TextSecondary}"/>
                                                    <TextBlock x:Name="MemoryTotal" Text="-- GB" FontSize="12" FontWeight="SemiBold" HorizontalAlignment="Right" Foreground="{StaticResource TextPrimary}"/>
                                                </Grid>
                                                <Grid Margin="0,5,0,0">
                                                    <TextBlock Text="Available:" FontSize="12" Foreground="{StaticResource TextSecondary}"/>
                                                    <TextBlock x:Name="MemoryAvailable" Text="-- GB" FontSize="12" FontWeight="SemiBold" HorizontalAlignment="Right" Foreground="{StaticResource SuccessColor}"/>
                                                </Grid>
                                                <Grid Margin="0,5,0,0">
                                                    <TextBlock Text="Used:" FontSize="12" Foreground="{StaticResource TextSecondary}"/>
                                                    <TextBlock x:Name="MemoryUsed" Text="-- GB" FontSize="12" FontWeight="SemiBold" HorizontalAlignment="Right" Foreground="{StaticResource WarningColor}"/>
                                                </Grid>
                                            </StackPanel>
                                        </Grid>
                                    </Grid>
                                </Border>

                                <Border Grid.Column="1" Style="{StaticResource Card}" Margin="8,0,0,0">
                                    <Grid>
                                        <Grid.RowDefinitions>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="*"/>
                                        </Grid.RowDefinitions>
                                        <TextBlock Grid.Row="0" Text="CPU Usage" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}"/>
                                        <TextBlock Grid.Row="1" x:Name="CPUPercent" Text="0%" FontSize="24" FontWeight="Bold" Foreground="{StaticResource SecondaryColor}" Margin="0,5,0,10"/>
                                        <Grid Grid.Row="2">
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="Auto"/>
                                                <ColumnDefinition Width="*"/>
                                            </Grid.ColumnDefinitions>
                                            <Border Grid.Column="0" Width="20" Height="80" CornerRadius="5" Background="{StaticResource SurfaceBg2}" Margin="0,0,15,0">
                                                <Border x:Name="CPUBar" Background="{StaticResource SecondaryColor}" CornerRadius="5" VerticalAlignment="Bottom" Height="0"/>
                                            </Border>
                                            <StackPanel Grid.Column="1">
                                                <Grid>
                                                    <TextBlock Text="Cores:" FontSize="12" Foreground="{StaticResource TextSecondary}"/>
                                                    <TextBlock x:Name="CPUCores" Text="--" FontSize="12" FontWeight="SemiBold" HorizontalAlignment="Right" Foreground="{StaticResource TextPrimary}"/>
                                                </Grid>
                                                <Grid Margin="0,5,0,0">
                                                    <TextBlock Text="Threads:" FontSize="12" Foreground="{StaticResource TextSecondary}"/>
                                                    <TextBlock x:Name="CPUThreads" Text="--" FontSize="12" FontWeight="SemiBold" HorizontalAlignment="Right" Foreground="{StaticResource TextPrimary}"/>
                                                </Grid>
                                                <Grid Margin="0,5,0,0">
                                                    <TextBlock Text="Processes:" FontSize="12" Foreground="{StaticResource TextSecondary}"/>
                                                    <TextBlock x:Name="ProcessCount" Text="--" FontSize="12" FontWeight="SemiBold" HorizontalAlignment="Right" Foreground="{StaticResource TextPrimary}"/>
                                                </Grid>
                                            </StackPanel>
                                        </Grid>
                                    </Grid>
                                </Border>
                            </Grid>

                            <!-- Activity Log -->
                            <Border Grid.Row="4" Style="{StaticResource Card}">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="*"/>
                                    </Grid.RowDefinitions>
                                    <TextBlock Grid.Row="0" Text="Recent Activity" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <ScrollViewer Grid.Row="1" MaxHeight="150" Style="{StaticResource ModernScrollViewer}">
                                        <StackPanel x:Name="ActivityLog">
                                            <TextBlock Text="No recent activity. Run an optimization to see results." FontSize="13" Foreground="{StaticResource TextMuted}" FontStyle="Italic"/>
                                        </StackPanel>
                                    </ScrollViewer>
                                </Grid>
                            </Border>
                        </Grid>
                    </ScrollViewer>
                </TabItem>

                <!-- CLEANING TAB -->
                <TabItem Header="Cleaning" Style="{StaticResource MainTabItem}">
                    <Grid Margin="20">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="300"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <Border Grid.Column="0" Style="{StaticResource Card}" Margin="0,0,15,0">
                            <ScrollViewer Style="{StaticResource ModernScrollViewer}">
                                <StackPanel>
                                    <TextBlock Text="Cleaning Categories" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,15"/>
                                    <Grid Margin="0,0,0,15">
                                        <Button x:Name="SelectAllCleanBtn" Content="Select All" Style="{StaticResource SecondaryButton}" Padding="10,6" HorizontalAlignment="Left" FontSize="12"/>
                                        <Button x:Name="DeselectAllCleanBtn" Content="Deselect All" Style="{StaticResource SecondaryButton}" Padding="10,6" HorizontalAlignment="Right" FontSize="12"/>
                                    </Grid>
                                    <Separator Background="{StaticResource BorderBrush}" Margin="0,0,0,15"/>
                                    <TextBlock Text="System Cleaning" FontSize="12" FontWeight="SemiBold" Foreground="{StaticResource TextMuted}" Margin="0,0,0,10"/>
                                    <CheckBox Content="User Temporary Files" x:Name="CleanUserTemp" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="System Temporary Files" x:Name="CleanSystemTemp" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="Windows Update Cache" x:Name="CleanWUCache" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="Recycle Bin" x:Name="CleanRecycleBin" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="Thumbnail Cache" x:Name="CleanThumbnailCache" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="Prefetch Files (Advanced)" x:Name="CleanPrefetch" Style="{StaticResource ModernCheckBox}" IsChecked="False"/>
                                    <Separator Background="{StaticResource BorderBrush}" Margin="0,15,0,15"/>
                                    <TextBlock Text="Browser Cleaning" FontSize="12" FontWeight="SemiBold" Foreground="{StaticResource TextMuted}" Margin="0,0,0,10"/>
                                    <CheckBox Content="Chrome Cache" x:Name="CleanChromeCache" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="Firefox Cache" x:Name="CleanFirefoxCache" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="Edge Cache" x:Name="CleanEdgeCache" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <Separator Background="{StaticResource BorderBrush}" Margin="0,15,0,15"/>
                                    <Button x:Name="ScanCleaningBtn" Content="Scan" Style="{StaticResource SecondaryButton}" Margin="0,0,0,10"/>
                                    <Button x:Name="RunCleaningBtn" Content="Run Cleaning" Style="{StaticResource ModernButton}" Margin="0,0,0,10"/>
                                    <Button x:Name="MasterCleanAllBtn" Content="Master Clean All" Style="{StaticResource SuccessButton}"/>
                                </StackPanel>
                            </ScrollViewer>
                        </Border>

                        <Border Grid.Column="1" Style="{StaticResource Card}">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                    <RowDefinition Height="Auto"/>
                                </Grid.RowDefinitions>
                                <Grid Grid.Row="0" Margin="0,0,0,15">
                                    <TextBlock Text="Cleaning Results" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}"/>
                                    <TextBlock x:Name="CleaningTotalSize" Text="Total: 0 GB recoverable" FontSize="14" Foreground="{StaticResource InfoColor}" HorizontalAlignment="Right"/>
                                </Grid>
                                <Border x:Name="CleaningProgressPanel" Grid.Row="1" Visibility="Collapsed" Background="{StaticResource SurfaceBg2}" CornerRadius="8" Padding="20">
                                    <StackPanel HorizontalAlignment="Center">
                                        <TextBlock x:Name="CleaningProgressTitle" Text="Cleaning..." FontSize="18" FontWeight="SemiBold" HorizontalAlignment="Center" Foreground="{StaticResource TextPrimary}"/>
                                        <TextBlock x:Name="CleaningProgressStatus" Text="Preparing..." FontSize="13" Foreground="{StaticResource TextSecondary}" HorizontalAlignment="Center" Margin="0,5,0,15"/>
                                        <ProgressBar x:Name="CleaningProgressBar" Style="{StaticResource ModernProgressBar}" Width="400" Value="0" Maximum="100"/>
                                        <TextBlock x:Name="CleaningProgressPercent" Text="0%" FontSize="14" FontWeight="SemiBold" HorizontalAlignment="Center" Margin="0,10,0,0" Foreground="{StaticResource PrimaryColor}"/>
                                    </StackPanel>
                                </Border>
                                <ScrollViewer Grid.Row="1" x:Name="CleaningResultsScroll" Style="{StaticResource ModernScrollViewer}">
                                    <Grid x:Name="CleaningResultsGrid">
                                        <TextBlock Text="Click 'Scan' to analyze recoverable space" FontSize="14" Foreground="{StaticResource TextMuted}" FontStyle="Italic" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="0,50"/>
                                    </Grid>
                                </ScrollViewer>
                                <Grid Grid.Row="2" Margin="0,15,0,0">
                                    <StackPanel Orientation="Horizontal">
                                        <TextBlock Text="Space Recovered: " FontSize="14" Foreground="{StaticResource TextSecondary}"/>
                                        <TextBlock x:Name="SpaceRecoveredText" Text="0 GB" FontSize="14" FontWeight="Bold" Foreground="{StaticResource SuccessColor}"/>
                                    </StackPanel>
                                    <Button x:Name="ExportCleaningReportBtn" Content="Export Report" Style="{StaticResource SecondaryButton}" HorizontalAlignment="Right" Padding="15,8" FontSize="12"/>
                                </Grid>
                            </Grid>
                        </Border>
                    </Grid>
                </TabItem>

                <!-- OPTIMIZATION TAB -->
                <TabItem Header="Optimization" Style="{StaticResource MainTabItem}">
                    <Grid Margin="20">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="300"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <Border Grid.Column="0" Style="{StaticResource Card}" Margin="0,0,15,0">
                            <ScrollViewer Style="{StaticResource ModernScrollViewer}">
                                <StackPanel>
                                    <TextBlock Text="Optimization Options" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,15"/>
                                    <TextBlock Text="Services Optimization" FontSize="12" FontWeight="SemiBold" Foreground="{StaticResource TextMuted}" Margin="0,0,0,10"/>
                                    <CheckBox Content="Privacy Services" x:Name="OptPrivacyServices" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="Performance Services" x:Name="OptPerfServices" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="Gaming Services" x:Name="OptGamingServices" Style="{StaticResource ModernCheckBox}" IsChecked="False"/>
                                    <Separator Background="{StaticResource BorderBrush}" Margin="0,15,0,15"/>
                                    <TextBlock Text="System Optimization" FontSize="12" FontWeight="SemiBold" Foreground="{StaticResource TextMuted}" Margin="0,0,0,10"/>
                                    <CheckBox Content="Optimize Startup Items" x:Name="OptStartup" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="Optimize Memory" x:Name="OptMemory" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="High Performance Plan" x:Name="OptPowerPlan" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="Disable Telemetry" x:Name="OptTelemetry" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <Separator Background="{StaticResource BorderBrush}" Margin="0,15,0,15"/>
                                    <Button x:Name="AnalyzeOptBtn" Content="Analyze" Style="{StaticResource SecondaryButton}" Margin="0,0,0,10"/>
                                    <Button x:Name="RunOptimizeBtn" Content="Run Optimization" Style="{StaticResource ModernButton}" Margin="0,0,0,10"/>
                                    <Button x:Name="CreateRestoreBtn" Content="Create Restore Point" Style="{StaticResource SecondaryButton}"/>
                                </StackPanel>
                            </ScrollViewer>
                        </Border>

                        <Border Grid.Column="1" Style="{StaticResource Card}">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                    <RowDefinition Height="Auto"/>
                                </Grid.RowDefinitions>
                                <TextBlock Grid.Row="0" Text="Optimization Results" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,15"/>
                                <Border x:Name="OptProgressPanel" Grid.Row="1" Visibility="Collapsed" Background="{StaticResource SurfaceBg2}" CornerRadius="8" Padding="20">
                                    <StackPanel HorizontalAlignment="Center">
                                        <TextBlock x:Name="OptProgressTitle" Text="Optimizing..." FontSize="18" FontWeight="SemiBold" HorizontalAlignment="Center"/>
                                        <TextBlock x:Name="OptProgressStatus" Text="Preparing..." FontSize="13" Foreground="{StaticResource TextSecondary}" HorizontalAlignment="Center" Margin="0,5,0,15"/>
                                        <ProgressBar x:Name="OptProgressBar" Style="{StaticResource ModernProgressBar}" Width="400" Value="0" Maximum="100"/>
                                        <TextBlock x:Name="OptProgressPercent" Text="0%" FontSize="14" FontWeight="SemiBold" HorizontalAlignment="Center" Margin="0,10,0,0" Foreground="{StaticResource PrimaryColor}"/>
                                    </StackPanel>
                                </Border>
                                <ScrollViewer Grid.Row="1" x:Name="OptResultsScroll" Style="{StaticResource ModernScrollViewer}">
                                    <StackPanel x:Name="OptResultsPanel">
                                        <Border Background="{StaticResource SurfaceBg2}" CornerRadius="8" Padding="15" Margin="0,0,0,10">
                                            <Grid>
                                                <Grid.RowDefinitions>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="*"/>
                                                </Grid.RowDefinitions>
                                                <TextBlock Grid.Row="0" Text="Startup Items" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,10"/>
                                                <StackPanel Grid.Row="1" x:Name="StartupItemsPanel">
                                                    <TextBlock Text="Click 'Analyze' to scan startup items" Foreground="{StaticResource TextMuted}" FontStyle="Italic"/>
                                                </StackPanel>
                                            </Grid>
                                        </Border>
                                        <Border Background="{StaticResource SurfaceBg2}" CornerRadius="8" Padding="15" Margin="0,0,0,10">
                                            <Grid>
                                                <Grid.RowDefinitions>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="*"/>
                                                </Grid.RowDefinitions>
                                                <TextBlock Grid.Row="0" Text="Services to Optimize" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,10"/>
                                                <StackPanel Grid.Row="1" x:Name="ServicesPanel">
                                                    <TextBlock Text="Click 'Analyze' to scan services" Foreground="{StaticResource TextMuted}" FontStyle="Italic"/>
                                                </StackPanel>
                                            </Grid>
                                        </Border>
                                        <Border Background="{StaticResource SurfaceBg2}" CornerRadius="8" Padding="15">
                                            <Grid>
                                                <Grid.RowDefinitions>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="*"/>
                                                </Grid.RowDefinitions>
                                                <TextBlock Grid.Row="0" Text="Performance Tips" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,10"/>
                                                <StackPanel Grid.Row="1" x:Name="PerformanceTipsPanel">
                                                    <TextBlock Text="Analysis will provide optimization recommendations" Foreground="{StaticResource TextMuted}" FontStyle="Italic"/>
                                                </StackPanel>
                                            </Grid>
                                        </Border>
                                    </StackPanel>
                                </ScrollViewer>
                                <Grid Grid.Row="2" Margin="0,15,0,0">
                                    <StackPanel Orientation="Horizontal">
                                        <TextBlock Text="Items Optimized: " FontSize="14" Foreground="{StaticResource TextSecondary}"/>
                                        <TextBlock x:Name="ItemsOptimizedText" Text="0" FontSize="14" FontWeight="Bold" Foreground="{StaticResource SuccessColor}"/>
                                    </StackPanel>
                                </Grid>
                            </Grid>
                        </Border>
                    </Grid>
                </TabItem>

                <!-- NETWORK TAB -->
                <TabItem Header="Network" Style="{StaticResource MainTabItem}">
                    <Grid Margin="20">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="300"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <Border Grid.Column="0" Style="{StaticResource Card}" Margin="0,0,15,0">
                            <ScrollViewer Style="{StaticResource ModernScrollViewer}">
                                <StackPanel>
                                    <TextBlock Text="Network Operations" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,15"/>
                                    <TextBlock Text="Network Reset" FontSize="12" FontWeight="SemiBold" Foreground="{StaticResource TextMuted}" Margin="0,0,0,10"/>
                                    <CheckBox Content="Reset TCP/IP Stack" x:Name="NetResetTCPIP" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="Reset Winsock Catalog" x:Name="NetResetWinsock" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="Flush DNS Cache" x:Name="NetFlushDNS" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="Clear ARP Cache" x:Name="NetClearARP" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="Reset Network Adapters" x:Name="NetResetAdapters" Style="{StaticResource ModernCheckBox}" IsChecked="False"/>
                                    <Separator Background="{StaticResource BorderBrush}" Margin="0,15,0,15"/>
                                    <TextBlock Text="Network Tuning" FontSize="12" FontWeight="SemiBold" Foreground="{StaticResource TextMuted}" Margin="0,0,0,10"/>
                                    <CheckBox Content="Optimize TCP Settings" x:Name="NetTuneTCP" Style="{StaticResource ModernCheckBox}" IsChecked="False"/>
                                    <CheckBox Content="Set DNS Servers (Google)" x:Name="NetSetDNS" Style="{StaticResource ModernCheckBox}" IsChecked="False"/>
                                    <Separator Background="{StaticResource BorderBrush}" Margin="0,15,0,15"/>
                                    <Button x:Name="RunNetworkBtn" Content="Run Network Reset" Style="{StaticResource ModernButton}" Margin="0,0,0,10"/>
                                    <Button x:Name="RunNetworkTuneBtn" Content="Run Network Tuning" Style="{StaticResource SecondaryButton}"/>
                                </StackPanel>
                            </ScrollViewer>
                        </Border>

                        <Border Grid.Column="1" Style="{StaticResource Card}">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <TextBlock Grid.Row="0" Text="Network Status and Results" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,15"/>
                                <ScrollViewer Grid.Row="1" Style="{StaticResource ModernScrollViewer}">
                                    <StackPanel>
                                        <Border Background="{StaticResource SurfaceBg2}" CornerRadius="8" Padding="15" Margin="0,0,0,10">
                                            <Grid>
                                                <Grid.RowDefinitions>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="*"/>
                                                </Grid.RowDefinitions>
                                                <TextBlock Grid.Row="0" Text="Network Adapters" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,10"/>
                                                <StackPanel Grid.Row="1" x:Name="NetworkAdaptersPanel">
                                                    <TextBlock Text="Loading..." Foreground="{StaticResource TextMuted}" FontStyle="Italic"/>
                                                </StackPanel>
                                            </Grid>
                                        </Border>
                                        <Border Background="{StaticResource SurfaceBg2}" CornerRadius="8" Padding="15" Margin="0,0,0,10">
                                            <Grid>
                                                <Grid.RowDefinitions>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="*"/>
                                                </Grid.RowDefinitions>
                                                <TextBlock Grid.Row="0" Text="DNS Configuration" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,10"/>
                                                <StackPanel Grid.Row="1" x:Name="DNSPanel">
                                                    <TextBlock Text="Loading..." Foreground="{StaticResource TextMuted}" FontStyle="Italic"/>
                                                </StackPanel>
                                            </Grid>
                                        </Border>
                                        <Border Background="{StaticResource SurfaceBg2}" CornerRadius="8" Padding="15">
                                            <Grid>
                                                <Grid.RowDefinitions>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="*"/>
                                                </Grid.RowDefinitions>
                                                <TextBlock Grid.Row="0" Text="Network Tests" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,10"/>
                                                <StackPanel Grid.Row="1" x:Name="NetworkTestsPanel">
                                                    <TextBlock Text="Click 'Run Network Reset' to test connectivity" Foreground="{StaticResource TextMuted}" FontStyle="Italic"/>
                                                </StackPanel>
                                            </Grid>
                                        </Border>
                                    </StackPanel>
                                </ScrollViewer>
                            </Grid>
                        </Border>
                    </Grid>
                </TabItem>

                <!-- TUNE TAB (Network Tuning) -->
                <TabItem Header="Tune" Style="{StaticResource MainTabItem}">
                    <Grid Margin="20">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="300"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <Border Grid.Column="0" Style="{StaticResource Card}" Margin="0,0,15,0">
                            <ScrollViewer Style="{StaticResource ModernScrollViewer}">
                                <StackPanel>
                                    <TextBlock Text="Network Tuning" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,15"/>
                                    <TextBlock Text="TCP/IP Optimization" FontSize="12" FontWeight="SemiBold" Foreground="{StaticResource TextMuted}" Margin="0,0,0,10"/>
                                    <CheckBox Content="Optimize TCP Settings" x:Name="TuneOptTCP" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="Optimize MTU" x:Name="TuneOptMTU" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="Optimize Network Buffers" x:Name="TuneOptBuffers" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <Separator Background="{StaticResource BorderBrush}" Margin="0,15,0,15"/>
                                    <TextBlock Text="QoS and Wi-Fi" FontSize="12" FontWeight="SemiBold" Foreground="{StaticResource TextMuted}" Margin="0,0,0,10"/>
                                    <CheckBox Content="Optimize QoS" x:Name="TuneOptQoS" Style="{StaticResource ModernCheckBox}" IsChecked="False"/>
                                    <CheckBox Content="Optimize Wi-Fi Power Management" x:Name="TuneOptWiFiPower" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <Separator Background="{StaticResource BorderBrush}" Margin="0,15,0,15"/>
                                    <TextBlock Text="DNS and Hosts" FontSize="12" FontWeight="SemiBold" Foreground="{StaticResource TextMuted}" Margin="0,0,0,10"/>
                                    <CheckBox Content="DNS Optimization (8.8.8.8 / 1.1.1.1)" x:Name="TuneOptDNS" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="Hosts File Management" x:Name="TuneOptHosts" Style="{StaticResource ModernCheckBox}" IsChecked="False"/>
                                    <Separator Background="{StaticResource BorderBrush}" Margin="0,15,0,15"/>
                                    <Button x:Name="AnalyzeTuneBtn" Content="Analyze" Style="{StaticResource SecondaryButton}" Margin="0,0,0,10"/>
                                    <Button x:Name="ApplyTuneBtn" Content="Apply Tuning" Style="{StaticResource ModernButton}"/>
                                </StackPanel>
                            </ScrollViewer>
                        </Border>

                        <Border Grid.Column="1" Style="{StaticResource Card}">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <TextBlock Grid.Row="0" Text="Tuning Results" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,15"/>
                                <Grid Grid.Row="1">
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="*"/>
                                        <RowDefinition Height="Auto"/>
                                    </Grid.RowDefinitions>
                                    <ScrollViewer Grid.Row="0" Style="{StaticResource ModernScrollViewer}">
                                        <StackPanel x:Name="TuneResultsPanel">
                                            <TextBlock Text="Click 'Analyze' to scan current network tuning status" FontSize="14" Foreground="{StaticResource TextMuted}" FontStyle="Italic"/>
                                        </StackPanel>
                                    </ScrollViewer>
                                    <ProgressBar Grid.Row="1" x:Name="TuneProgressBar" Style="{StaticResource ModernProgressBar}" Value="0" Maximum="100" Margin="0,10,0,0"/>
                                </Grid>
                            </Grid>
                        </Border>
                    </Grid>
                </TabItem>

                <!-- REPAIR TAB -->
                <TabItem Header="Repair" Style="{StaticResource MainTabItem}">
                    <Grid Margin="20">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="300"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <Border Grid.Column="0" Style="{StaticResource Card}" Margin="0,0,15,0">
                            <ScrollViewer Style="{StaticResource ModernScrollViewer}">
                                <StackPanel>
                                    <TextBlock Text="Repair Operations" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,15"/>
                                    <Button x:Name="RunSFCBtn" Content="Run SFC Scan" Style="{StaticResource ModernButton}" Margin="0,0,0,10" HorizontalContentAlignment="Left"/>
                                    <TextBlock Text="System File Checker - scans and repairs corrupted system files" FontSize="11" Foreground="{StaticResource TextMuted}" Margin="0,-5,0,10" TextWrapping="Wrap"/>
                                    <Button x:Name="RunDISMCheckBtn" Content="Run DISM CheckHealth" Style="{StaticResource ModernButton}" Margin="0,0,0,10" HorizontalContentAlignment="Left"/>
                                    <TextBlock Text="Checks for component store corruption markers" FontSize="11" Foreground="{StaticResource TextMuted}" Margin="0,-5,0,10" TextWrapping="Wrap"/>
                                    <Button x:Name="RunDISMRestoreBtn" Content="Run DISM RestoreHealth" Style="{StaticResource ModernButton}" Margin="0,0,0,10" HorizontalContentAlignment="Left"/>
                                    <TextBlock Text="Repairs component store using Windows Update" FontSize="11" Foreground="{StaticResource TextMuted}" Margin="0,-5,0,10" TextWrapping="Wrap"/>
                                    <Button x:Name="RunFullRepairBtn" Content="Run Full System Repair" Style="{StaticResource SuccessButton}" Margin="0,0,0,10" HorizontalContentAlignment="Left"/>
                                    <TextBlock Text="DISM RestoreHealth + SFC combined for comprehensive repair" FontSize="11" Foreground="{StaticResource TextMuted}" Margin="0,-5,0,10" TextWrapping="Wrap"/>
                                    <Button x:Name="RunWURepairBtn" Content="Windows Update Repair" Style="{StaticResource SecondaryButton}" Margin="0,0,0,10" HorizontalContentAlignment="Left"/>
                                    <TextBlock Text="Resets Windows Update components and cache" FontSize="11" Foreground="{StaticResource TextMuted}" Margin="0,-5,0,10" TextWrapping="Wrap"/>
                                    <Button x:Name="RunDefenderCleanupBtn" Content="Windows Defender Log Cleanup" Style="{StaticResource SecondaryButton}" Margin="0,0,0,10" HorizontalContentAlignment="Left"/>
                                    <TextBlock Text="Clears old Defender scan logs and quarantine" FontSize="11" Foreground="{StaticResource TextMuted}" Margin="0,-5,0,0" TextWrapping="Wrap"/>
                                </StackPanel>
                            </ScrollViewer>
                        </Border>

                        <Border Grid.Column="1" Style="{StaticResource Card}">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                    <RowDefinition Height="Auto"/>
                                </Grid.RowDefinitions>
                                <TextBlock Grid.Row="0" Text="Repair Output" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,15"/>
                                <Border Grid.Row="1" Background="#0A0A14" CornerRadius="8" Padding="15">
                                    <ScrollViewer Style="{StaticResource ModernScrollViewer}">
                                        <TextBlock x:Name="RepairOutputText" Text="Select a repair operation to begin." FontSize="12" Foreground="#90EE90" FontFamily="Consolas" TextWrapping="Wrap"/>
                                    </ScrollViewer>
                                </Border>
                                <Grid Grid.Row="2" Margin="0,10,0,0">
                                    <ProgressBar x:Name="RepairProgressBar" Style="{StaticResource ModernProgressBar}" Value="0" Maximum="100"/>
                                    <TextBlock x:Name="RepairStatusText" Text="Ready" FontSize="12" Foreground="{StaticResource TextSecondary}" HorizontalAlignment="Center"/>
                                </Grid>
                            </Grid>
                        </Border>
                    </Grid>
                </TabItem>

                <!-- TUNING TAB -->
                <TabItem Header="Tuning" Style="{StaticResource MainTabItem}">
                    <Grid Margin="20">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="300"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <Border Grid.Column="0" Style="{StaticResource Card}" Margin="0,0,15,0">
                            <ScrollViewer Style="{StaticResource ModernScrollViewer}">
                                <StackPanel>
                                    <TextBlock Text="OS Tuning Options" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,15"/>
                                    <TextBlock Text="Boot Optimization" FontSize="12" FontWeight="SemiBold" Foreground="{StaticResource TextMuted}" Margin="0,0,0,10"/>
                                    <CheckBox Content="Optimize Boot Time" x:Name="TuneBootTime" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="Disable Fast Boot" x:Name="TuneFastBoot" Style="{StaticResource ModernCheckBox}" IsChecked="False"/>
                                    <CheckBox Content="Optimize Boot Services" x:Name="TuneBootServices" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <Separator Background="{StaticResource BorderBrush}" Margin="0,15,0,15"/>
                                    <TextBlock Text="UI Optimization" FontSize="12" FontWeight="SemiBold" Foreground="{StaticResource TextMuted}" Margin="0,0,0,10"/>
                                    <CheckBox Content="Disable Animations" x:Name="TuneAnimations" Style="{StaticResource ModernCheckBox}" IsChecked="False"/>
                                    <CheckBox Content="Reduce Visual Effects" x:Name="TuneVisualEffects" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <CheckBox Content="Optimize Menu Speed" x:Name="TuneMenuSpeed" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <Separator Background="{StaticResource BorderBrush}" Margin="0,15,0,15"/>
                                    <TextBlock Text="System Tweaks" FontSize="12" FontWeight="SemiBold" Foreground="{StaticResource TextMuted}" Margin="0,0,0,10"/>
                                    <CheckBox Content="Disable Cortana" x:Name="TuneCortana" Style="{StaticResource ModernCheckBox}" IsChecked="False"/>
                                    <CheckBox Content="Disable Search Indexing" x:Name="TuneSearchIndex" Style="{StaticResource ModernCheckBox}" IsChecked="False"/>
                                    <CheckBox Content="Optimize NTFS" x:Name="TuneNTFS" Style="{StaticResource ModernCheckBox}" IsChecked="True"/>
                                    <Separator Background="{StaticResource BorderBrush}" Margin="0,15,0,15"/>
                                    <Button x:Name="RunTuningBtn" Content="Apply Tuning" Style="{StaticResource ModernButton}" Margin="0,0,0,10"/>
                                    <Button x:Name="RestoreDefaultsBtn" Content="Restore Defaults" Style="{StaticResource SecondaryButton}"/>
                                </StackPanel>
                            </ScrollViewer>
                        </Border>

                        <Border Grid.Column="1" Style="{StaticResource Card}">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <TextBlock Grid.Row="0" Text="System Tuning Status" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,15"/>
                                <ScrollViewer Grid.Row="1" Style="{StaticResource ModernScrollViewer}">
                                    <StackPanel>
                                        <Border Background="{StaticResource SurfaceBg2}" CornerRadius="8" Padding="15" Margin="0,0,0,10">
                                            <Grid>
                                                <Grid.RowDefinitions>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="*"/>
                                                </Grid.RowDefinitions>
                                                <TextBlock Grid.Row="0" Text="Boot Configuration" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,10"/>
                                                <StackPanel Grid.Row="1" x:Name="BootConfigPanel">
                                                    <TextBlock Text="Analyzing boot configuration..." Foreground="{StaticResource TextMuted}" FontStyle="Italic"/>
                                                </StackPanel>
                                            </Grid>
                                        </Border>
                                        <Border Background="{StaticResource SurfaceBg2}" CornerRadius="8" Padding="15" Margin="0,0,0,10">
                                            <Grid>
                                                <Grid.RowDefinitions>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="*"/>
                                                </Grid.RowDefinitions>
                                                <TextBlock Grid.Row="0" Text="Visual Effects" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,10"/>
                                                <StackPanel Grid.Row="1" x:Name="VisualEffectsPanel">
                                                    <TextBlock Text="Analyzing visual settings..." Foreground="{StaticResource TextMuted}" FontStyle="Italic"/>
                                                </StackPanel>
                                            </Grid>
                                        </Border>
                                        <Border Background="{StaticResource SurfaceBg2}" CornerRadius="8" Padding="15">
                                            <Grid>
                                                <Grid.RowDefinitions>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="*"/>
                                                </Grid.RowDefinitions>
                                                <TextBlock Grid.Row="0" Text="Applied Tweaks" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,10"/>
                                                <StackPanel Grid.Row="1" x:Name="AppliedTweaksPanel">
                                                    <TextBlock Text="No tweaks applied yet" Foreground="{StaticResource TextMuted}" FontStyle="Italic"/>
                                                </StackPanel>
                                            </Grid>
                                        </Border>
                                    </StackPanel>
                                </ScrollViewer>
                            </Grid>
                        </Border>
                    </Grid>
                </TabItem>

                <!-- REPORTS TAB -->
                <TabItem Header="Reports" Style="{StaticResource MainTabItem}">
                    <ScrollViewer Style="{StaticResource ModernScrollViewer}" Padding="20">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <!-- Generate Health Report Button -->
                            <Border Grid.Row="0" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel HorizontalAlignment="Center">
                                    <Button x:Name="GenerateHealthReportBtn" Content="Generate Health Report" Style="{StaticResource SuccessButton}" Padding="30,15" FontSize="16"/>
                                    <TextBlock Text="Comprehensive system analysis with scoring" FontSize="12" Foreground="{StaticResource TextSecondary}" HorizontalAlignment="Center" Margin="0,8,0,0"/>
                                </StackPanel>
                            </Border>

                            <!-- Health Score and Category Breakdown -->
                            <Grid Grid.Row="1" Margin="0,0,0,15">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="2*"/>
                                </Grid.ColumnDefinitions>

                                <!-- Health Score Gauge -->
                                <Border Grid.Column="0" Style="{StaticResource Card}" Margin="0,0,10,0">
                                    <StackPanel HorizontalAlignment="Center">
                                        <TextBlock Text="Health Score" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" HorizontalAlignment="Center" Margin="0,0,0,15"/>
                                        <Viewbox Width="130" Height="130">
                                            <Grid>
                                                <Ellipse Width="120" Height="120" Stroke="{StaticResource SurfaceBg2}" StrokeThickness="14"/>
                                                <Ellipse x:Name="ReportHealthCircle" Width="120" Height="120" Stroke="{StaticResource SuccessColor}" StrokeThickness="14" StrokeDashArray="100 377" StrokeDashCap="Round" RenderTransformOrigin="0.5,0.5">
                                                    <Ellipse.RenderTransform>
                                                        <RotateTransform Angle="-90"/>
                                                    </Ellipse.RenderTransform>
                                                </Ellipse>
                                                <TextBlock x:Name="ReportHealthScore" Text="--" FontSize="38" FontWeight="Bold" Foreground="{StaticResource TextPrimary}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                            </Grid>
                                        </Viewbox>
                                        <TextBlock x:Name="ReportHealthLabel" Text="Run report to score" FontSize="12" Foreground="{StaticResource TextSecondary}" HorizontalAlignment="Center" Margin="0,10,0,0"/>
                                    </StackPanel>
                                </Border>

                                <!-- Category Breakdown -->
                                <Border Grid.Column="1" Style="{StaticResource Card}">
                                    <StackPanel>
                                        <TextBlock Text="Category Breakdown" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,12"/>
                                        <Grid Margin="0,0,0,8">
                                            <TextBlock Text="[DISK] Disk" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                            <TextBlock x:Name="ReportDiskScore" Text="--" FontSize="13" FontWeight="SemiBold" Foreground="{StaticResource InfoColor}" HorizontalAlignment="Right"/>
                                        </Grid>
                                        <Grid Margin="0,0,0,8">
                                            <TextBlock Text="[STARTUP] Startup" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                            <TextBlock x:Name="ReportStartupScore" Text="--" FontSize="13" FontWeight="SemiBold" Foreground="{StaticResource AccentColor}" HorizontalAlignment="Right"/>
                                        </Grid>
                                        <Grid Margin="0,0,0,8">
                                            <TextBlock Text="[SVC] Services" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                            <TextBlock x:Name="ReportServicesScore" Text="--" FontSize="13" FontWeight="SemiBold" Foreground="{StaticResource PrimaryColor}" HorizontalAlignment="Right"/>
                                        </Grid>
                                        <Grid Margin="0,0,0,8">
                                            <TextBlock Text="[NET] Network" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                            <TextBlock x:Name="ReportNetworkScore" Text="--" FontSize="13" FontWeight="SemiBold" Foreground="{StaticResource SecondaryColor}" HorizontalAlignment="Right"/>
                                        </Grid>
                                        <Grid Margin="0,0,0,8">
                                            <TextBlock Text="[PRIV] Privacy" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                            <TextBlock x:Name="ReportPrivacyScore" Text="--" FontSize="13" FontWeight="SemiBold" Foreground="{StaticResource WarningColor}" HorizontalAlignment="Right"/>
                                        </Grid>
                                        <Grid>
                                            <TextBlock Text="[SEC] Security" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                            <TextBlock x:Name="ReportSecurityScore" Text="--" FontSize="13" FontWeight="SemiBold" Foreground="{StaticResource DangerColor}" HorizontalAlignment="Right"/>
                                        </Grid>
                                    </StackPanel>
                                </Border>
                            </Grid>

                            <!-- Export and Previous Reports -->
                            <Grid Grid.Row="2" Margin="0,0,0,15">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>

                                <Border Grid.Column="0" Style="{StaticResource Card}" Margin="0,0,10,0">
                                    <StackPanel>
                                        <TextBlock Text="Export Report" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                        <TextBlock Text="Export the latest health report to HTML format for sharing or archiving." FontSize="12" Foreground="{StaticResource TextSecondary}" TextWrapping="Wrap" Margin="0,0,0,12"/>
                                        <Button x:Name="ExportHTMLReportBtn" Content="Export to HTML" Style="{StaticResource ModernButton}" HorizontalAlignment="Left"/>
                                    </StackPanel>
                                </Border>

                                <Border Grid.Column="1" Style="{StaticResource Card}">
                                    <StackPanel>
                                        <TextBlock Text="Quick Actions" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                        <Button x:Name="OpenReportsFolderBtn" Content="Open Reports Folder" Style="{StaticResource SecondaryButton}" Margin="0,0,0,8" HorizontalAlignment="Left"/>
                                        <Button x:Name="ClearReportsBtn" Content="Clear Old Reports" Style="{StaticResource SecondaryButton}" HorizontalAlignment="Left"/>
                                    </StackPanel>
                                </Border>
                            </Grid>

                            <!-- View Previous Reports -->
                            <Border Grid.Row="3" Style="{StaticResource Card}">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="*"/>
                                    </Grid.RowDefinitions>
                                    <TextBlock Grid.Row="0" Text="View Previous Reports" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <ScrollViewer Grid.Row="1" Style="{StaticResource ModernScrollViewer}" MaxHeight="180">
                                        <StackPanel x:Name="ReportsListPanel">
                                            <TextBlock Text="No reports generated yet. Click 'Generate Health Report' to create one." FontSize="12" Foreground="{StaticResource TextMuted}" FontStyle="Italic"/>
                                        </StackPanel>
                                    </ScrollViewer>
                                </Grid>
                            </Border>
                        </Grid>
                    </ScrollViewer>
                </TabItem>

                <!-- SETTINGS TAB -->
                <TabItem Header="Settings" Style="{StaticResource MainTabItem}">
                    <ScrollViewer Style="{StaticResource ModernScrollViewer}" Margin="20">
                        <StackPanel>
                            <!-- General -->
                            <Border Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel>
                                    <TextBlock Text="General" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,15"/>
                                    <Grid Margin="0,0,0,12">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Grid.Column="0" Text="Theme:" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center" Margin="0,0,15,0"/>
                                        <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                            <TextBlock Text="Changes the application color scheme" FontSize="11" Foreground="{StaticResource TextSecondary}"/>
                                            <TextBlock Text="Effect: Immediately re-colors all UI elements" FontSize="11" Foreground="{StaticResource TextMuted}"/>
                                        </StackPanel>
                                        <ComboBox x:Name="SettingThemeSelect" Grid.Column="2" Width="140" Height="28" Background="{StaticResource SurfaceBg2}" Foreground="{StaticResource TextPrimary}" BorderBrush="{StaticResource BorderBrush}">
                                            <ComboBoxItem Content="Dark" IsSelected="True"/>
                                            <ComboBoxItem Content="Light"/>
                                        </ComboBox>
                                    </Grid>
                                    <Grid Margin="0,0,0,12">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Grid.Column="0" Text="Log Level:" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center" Margin="0,0,15,0"/>
                                        <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                            <TextBlock Text="Controls how much detail is written to log files" FontSize="11" Foreground="{StaticResource TextSecondary}"/>
                                            <TextBlock Text="Effect: Higher levels increase log file size; Debug is for troubleshooting only" FontSize="11" Foreground="{StaticResource TextMuted}"/>
                                            <TextBlock Text="Advice: Use Standard for daily use. Switch to Verbose or Debug only when reporting issues" FontSize="11" Foreground="{StaticResource PrimaryColor}"/>
                                        </StackPanel>
                                        <ComboBox x:Name="SettingLogLevel" Grid.Column="2" Width="140" Height="28" Background="{StaticResource SurfaceBg2}" Foreground="{StaticResource TextPrimary}" BorderBrush="{StaticResource BorderBrush}">
                                            <ComboBoxItem Content="Minimal"/>
                                            <ComboBoxItem Content="Standard" IsSelected="True"/>
                                            <ComboBoxItem Content="Verbose"/>
                                            <ComboBoxItem Content="Debug"/>
                                        </ComboBox>
                                    </Grid>
                                    <Grid Margin="0,0,0,12">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Grid.Column="0" Text="Backup Retention:" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center" Margin="0,0,15,0"/>
                                        <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                            <TextBlock Text="Number of days to keep backup files before auto-cleanup" FontSize="11" Foreground="{StaticResource TextSecondary}"/>
                                            <TextBlock Text="Effect: Backups older than this are deleted during maintenance" FontSize="11" Foreground="{StaticResource TextMuted}"/>
                                            <TextBlock Text="Advice: 30 days is safe. Reduce to 7 if disk space is limited" FontSize="11" Foreground="{StaticResource PrimaryColor}"/>
                                        </StackPanel>
                                        <TextBox x:Name="SettingBackupRetention" Grid.Column="2" Width="70" Height="28" Text="30" Background="{StaticResource SurfaceBg2}" Foreground="{StaticResource TextPrimary}" BorderBrush="{StaticResource BorderBrush}" TextAlignment="Center" VerticalContentAlignment="Center"/>
                                    </Grid>
                                    <Grid Margin="0,0,0,12">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0">
                                            <TextBlock Text="Auto-delete Old Backups" FontSize="13" Foreground="{StaticResource TextPrimary}"/>
                                            <TextBlock Text="Automatically removes backup files exceeding retention period" FontSize="11" Foreground="{StaticResource TextSecondary}"/>
                                            <TextBlock Text="Effect: Saves disk space but removes ability to restore from old backups" FontSize="11" Foreground="{StaticResource TextMuted}"/>
                                            <TextBlock Text="Advice: Enable to prevent backup folder from growing indefinitely" FontSize="11" Foreground="{StaticResource PrimaryColor}"/>
                                        </StackPanel>
                                        <CheckBox x:Name="SettingAutoDeleteBackups" Grid.Column="1" Style="{StaticResource ModernCheckBox}" VerticalAlignment="Center" IsChecked="True"/>
                                    </Grid>
                                    <Grid Margin="0,0,0,12">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0">
                                            <TextBlock Text="Show Confirmations" FontSize="13" Foreground="{StaticResource TextPrimary}"/>
                                            <TextBlock Text="Display confirmation dialogs before applying changes" FontSize="11" Foreground="{StaticResource TextSecondary}"/>
                                            <TextBlock Text="Effect: Disabling skips all safety prompts and applies changes immediately" FontSize="11" Foreground="{StaticResource TextMuted}"/>
                                            <TextBlock Text="Advice: Keep enabled to prevent accidental changes" FontSize="11" Foreground="{StaticResource PrimaryColor}"/>
                                        </StackPanel>
                                        <CheckBox x:Name="SettingConfirmations" Grid.Column="1" Style="{StaticResource ModernCheckBox}" VerticalAlignment="Center" IsChecked="True"/>
                                    </Grid>
                                    <Grid Margin="0,0,0,12">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0">
                                            <TextBlock Text="Test Mode" FontSize="13" Foreground="{StaticResource TextPrimary}"/>
                                            <TextBlock Text="Simulate all operations without making actual system changes" FontSize="11" Foreground="{StaticResource TextSecondary}"/>
                                            <TextBlock Text="Effect: All operations report success but nothing is modified on the system" FontSize="11" Foreground="{StaticResource TextMuted}"/>
                                            <TextBlock Text="Advice: Enable when testing new configurations or learning the tool" FontSize="11" Foreground="{StaticResource PrimaryColor}"/>
                                        </StackPanel>
                                        <CheckBox x:Name="SettingTestMode" Grid.Column="1" Style="{StaticResource ModernCheckBox}" VerticalAlignment="Center" IsChecked="False"/>
                                    </Grid>
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Grid.Column="0" Text="Scan Exclusions:" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center" Margin="0,0,15,0"/>
                                        <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                            <TextBlock Text="Comma-separated paths to exclude from all scans and cleaning" FontSize="11" Foreground="{StaticResource TextSecondary}"/>
                                            <TextBlock Text="Effect: Excluded paths are skipped during all scan and clean operations" FontSize="11" Foreground="{StaticResource TextMuted}"/>
                                            <TextBlock Text="Advice: Add paths to sensitive directories or large data folders you never want touched" FontSize="11" Foreground="{StaticResource PrimaryColor}"/>
                                        </StackPanel>
                                        <TextBox x:Name="SettingScanExclusions" Grid.Column="2" Width="200" Height="28" Background="{StaticResource SurfaceBg2}" Foreground="{StaticResource TextPrimary}" BorderBrush="{StaticResource BorderBrush}" VerticalContentAlignment="Center"/>
                                    </Grid>
                                </StackPanel>
                            </Border>

                            <!-- Cleaning -->
                            <Border Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel>
                                    <TextBlock Text="Cleaning" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,15"/>
                                    <Grid Margin="0,0,0,12">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0">
                                            <TextBlock Text="Auto-create Restore Point" FontSize="13" Foreground="{StaticResource TextPrimary}"/>
                                            <TextBlock Text="Creates a system restore point before each cleaning operation" FontSize="11" Foreground="{StaticResource TextSecondary}"/>
                                            <TextBlock Text="Effect: Adds 10-30 seconds to operation time but provides rollback safety" FontSize="11" Foreground="{StaticResource TextMuted}"/>
                                            <TextBlock Text="Advice: Strongly recommended. Disable only if restore points consume too much disk space" FontSize="11" Foreground="{StaticResource PrimaryColor}"/>
                                        </StackPanel>
                                        <CheckBox x:Name="SettingAutoRestore" Grid.Column="1" Style="{StaticResource ModernCheckBox}" VerticalAlignment="Center" IsChecked="True"/>
                                    </Grid>
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0">
                                            <TextBlock Text="Auto-generate Reports" FontSize="13" Foreground="{StaticResource TextPrimary}"/>
                                            <TextBlock Text="Automatically generate a report after each optimization run" FontSize="11" Foreground="{StaticResource TextSecondary}"/>
                                            <TextBlock Text="Effect: Creates HTML report file in the Reports folder after each operation" FontSize="11" Foreground="{StaticResource TextMuted}"/>
                                            <TextBlock Text="Advice: Useful for tracking system changes over time" FontSize="11" Foreground="{StaticResource PrimaryColor}"/>
                                        </StackPanel>
                                        <CheckBox x:Name="SettingAutoReports" Grid.Column="1" Style="{StaticResource ModernCheckBox}" VerticalAlignment="Center" IsChecked="True"/>
                                    </Grid>
                                </StackPanel>
                            </Border>

                            <!-- Optimization -->
                            <Border Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel>
                                    <TextBlock Text="Optimization" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,15"/>
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Grid.Column="0" Text="Optimization Mode:" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center" Margin="0,0,15,0"/>
                                        <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                            <TextBlock Text="Controls how aggressively the optimizer applies changes" FontSize="11" Foreground="{StaticResource TextSecondary}"/>
                                            <TextBlock Text="Effect: Aggressive mode enables more tweaks but higher risk of side effects" FontSize="11" Foreground="{StaticResource TextMuted}"/>
                                            <TextBlock Text="Advice: Start with Conservative; switch to Balanced once comfortable" FontSize="11" Foreground="{StaticResource PrimaryColor}"/>
                                        </StackPanel>
                                        <ComboBox x:Name="SettingOptMode" Grid.Column="2" Width="140" Height="28" Background="{StaticResource SurfaceBg2}" Foreground="{StaticResource TextPrimary}" BorderBrush="{StaticResource BorderBrush}">
                                            <ComboBoxItem Content="Conservative"/>
                                            <ComboBoxItem Content="Balanced" IsSelected="True"/>
                                            <ComboBoxItem Content="Aggressive"/>
                                        </ComboBox>
                                    </Grid>
                                </StackPanel>
                            </Border>

                            <!-- Network -->
                            <Border Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel>
                                    <TextBlock Text="Network" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,15"/>
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Grid.Column="0" Text="Default DNS:" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center" Margin="0,0,15,0"/>
                                        <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                            <TextBlock Text="DNS server to use when applying DNS optimizations" FontSize="11" Foreground="{StaticResource TextSecondary}"/>
                                            <TextBlock Text="Effect: Changes system-wide DNS resolution to the selected provider" FontSize="11" Foreground="{StaticResource TextMuted}"/>
                                            <TextBlock Text="Advice: Cloudflare is fastest; Google is most reliable; Quad9 adds malware blocking" FontSize="11" Foreground="{StaticResource PrimaryColor}"/>
                                        </StackPanel>
                                        <ComboBox x:Name="SettingDefaultDNS" Grid.Column="2" Width="160" Height="28" Background="{StaticResource SurfaceBg2}" Foreground="{StaticResource TextPrimary}" BorderBrush="{StaticResource BorderBrush}">
                                            <ComboBoxItem Content="Cloudflare (1.1.1.1)" IsSelected="True"/>
                                            <ComboBoxItem Content="Google (8.8.8.8)"/>
                                            <ComboBoxItem Content="Quad9 (9.9.9.9)"/>
                                            <ComboBoxItem Content="OpenDNS"/>
                                            <ComboBoxItem Content="System Default"/>
                                        </ComboBox>
                                    </Grid>
                                </StackPanel>
                            </Border>

                            <!-- Safety -->
                            <Border Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel>
                                    <TextBlock Text="Safety" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,15"/>
                                    <Grid Margin="0,0,0,12">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0">
                                            <TextBlock Text="Warn on Critical Systems" FontSize="13" Foreground="{StaticResource TextPrimary}"/>
                                            <TextBlock Text="Show warning when operating on domain controllers or servers" FontSize="11" Foreground="{StaticResource TextSecondary}"/>
                                            <TextBlock Text="Effect: Displays additional confirmation step on critical system types" FontSize="11" Foreground="{StaticResource TextMuted}"/>
                                            <TextBlock Text="Advice: Always keep enabled on production servers" FontSize="11" Foreground="{StaticResource PrimaryColor}"/>
                                        </StackPanel>
                                        <CheckBox x:Name="SettingWarnCritical" Grid.Column="1" Style="{StaticResource ModernCheckBox}" VerticalAlignment="Center" IsChecked="True"/>
                                    </Grid>
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <StackPanel Grid.Column="0">
                                            <TextBlock Text="Block High-Risk Operations" FontSize="13" Foreground="{StaticResource TextPrimary}"/>
                                            <TextBlock Text="Prevents potentially dangerous operations on critical systems" FontSize="11" Foreground="{StaticResource TextSecondary}"/>
                                            <TextBlock Text="Effect: Completely blocks operations that could destabilize critical infrastructure" FontSize="11" Foreground="{StaticResource TextMuted}"/>
                                            <TextBlock Text="Advice: Enable on production systems. Disable only in test environments" FontSize="11" Foreground="{StaticResource PrimaryColor}"/>
                                        </StackPanel>
                                        <CheckBox x:Name="SettingBlockCritical" Grid.Column="1" Style="{StaticResource ModernCheckBox}" VerticalAlignment="Center" IsChecked="True"/>
                                    </Grid>
                                </StackPanel>
                            </Border>

                            <!-- Appearance -->
                            <Border Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel>
                                    <TextBlock Text="Appearance" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,15"/>
                                    <Grid Margin="0,0,0,15">
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Grid.Column="0" Text="Theme:" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center" Margin="0,0,15,0"/>
                                        <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                            <TextBlock Text="Application color theme" FontSize="11" Foreground="{StaticResource TextSecondary}"/>
                                            <TextBlock Text="Effect: Changes the look and feel of the entire UI" FontSize="11" Foreground="{StaticResource TextMuted}"/>
                                        </StackPanel>
                                        <ComboBox x:Name="SettingTheme" Grid.Column="2" Width="120" Height="28" Background="{StaticResource SurfaceBg2}" Foreground="{StaticResource TextPrimary}" BorderBrush="{StaticResource BorderBrush}">
                                            <ComboBoxItem Content="Dark" IsSelected="True"/>
                                            <ComboBoxItem Content="Light"/>
                                        </ComboBox>
                                    </Grid>
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Grid.Column="0" Text="Font Size:" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center" Margin="0,0,15,0"/>
                                        <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                            <TextBlock Text="Base font size for the application UI" FontSize="11" Foreground="{StaticResource TextSecondary}"/>
                                            <TextBlock Text="Effect: Scales all text elements; requires restart to take full effect" FontSize="11" Foreground="{StaticResource TextMuted}"/>
                                            <TextBlock Text="Advice: 13 is the default. Increase for high-DPI displays" FontSize="11" Foreground="{StaticResource PrimaryColor}"/>
                                        </StackPanel>
                                        <ComboBox x:Name="SettingFontSize" Grid.Column="2" Width="100" Height="28" Background="{StaticResource SurfaceBg2}" Foreground="{StaticResource TextPrimary}" BorderBrush="{StaticResource BorderBrush}">
                                            <ComboBoxItem Content="11"/>
                                            <ComboBoxItem Content="12"/>
                                            <ComboBoxItem Content="13" IsSelected="True"/>
                                            <ComboBoxItem Content="14"/>
                                            <ComboBoxItem Content="16"/>
                                        </ComboBox>
                                    </Grid>
                                </StackPanel>
                            </Border>

                            <!-- About -->
                            <Border Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel>
                                    <TextBlock Text="About WinTune Pro" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,15"/>
                                    <Grid Margin="0,0,0,5">
                                        <TextBlock Text="Version:" FontSize="13" Foreground="{StaticResource TextSecondary}"/>
                                        <TextBlock Text="2.0.0" FontSize="13" Foreground="{StaticResource TextPrimary}" HorizontalAlignment="Right"/>
                                    </Grid>
                                    <Grid Margin="0,0,0,5">
                                        <TextBlock Text="Author:" FontSize="13" Foreground="{StaticResource TextSecondary}"/>
                                        <TextBlock Text="WinTune Pro Development Team" FontSize="13" Foreground="{StaticResource TextPrimary}" HorizontalAlignment="Right"/>
                                    </Grid>
                                    <Grid>
                                        <TextBlock Text="PowerShell Version:" FontSize="13" Foreground="{StaticResource TextSecondary}"/>
                                        <TextBlock x:Name="PSVersionText" Text="--" FontSize="13" Foreground="{StaticResource TextPrimary}" HorizontalAlignment="Right"/>
                                    </Grid>
                                </StackPanel>
                            </Border>

                            <!-- Buttons -->
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,20">
                                <Button x:Name="SaveSettingsBtn" Content="Save Settings" Style="{StaticResource SuccessButton}" Margin="0,0,10,0"/>
                                <Button x:Name="ResetSettingsBtn" Content="Reset to Defaults" Style="{StaticResource SecondaryButton}"/>
                            </StackPanel>
                        </StackPanel>
                    </ScrollViewer>
                </TabItem>

                <!-- BENCHMARK TAB -->
                <TabItem Header="Benchmark" Style="{StaticResource MainTabItem}">
                    <ScrollViewer Style="{StaticResource ModernScrollViewer}" Padding="20">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>

                            <Border Grid.Row="0" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <Grid>
                                    <StackPanel Orientation="Horizontal">
                                        <Button x:Name="RunBenchmarkBtn" Content="Run Full Benchmark" Style="{StaticResource SuccessButton}" Margin="0,0,10,0" Width="160"/>
                                        <Button x:Name="QuickBenchmarkBtn" Content="Quick Benchmark" Style="{StaticResource ModernButton}" Margin="0,0,10,0" Width="140"/>
                                        <Button x:Name="ExportBenchmarkBtn" Content="Export Results" Style="{StaticResource SecondaryButton}"/>
                                    </StackPanel>
                                    <TextBlock x:Name="BenchmarkDuration" Text="" FontSize="12" Foreground="{StaticResource TextSecondary}" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>

                            <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0" Orientation="Horizontal" Margin="0,0,30,0">
                                        <TextBlock Text="Overall Score: " FontSize="20" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                        <TextBlock x:Name="OverallBenchmarkScore" Text="--" FontSize="36" FontWeight="Bold" Foreground="{StaticResource PrimaryColor}" VerticalAlignment="Center"/>
                                        <TextBlock x:Name="OverallBenchmarkRating" Text="" FontSize="16" Foreground="{StaticResource SuccessColor}" VerticalAlignment="Center" Margin="10,0,0,0"/>
                                    </StackPanel>
                                    <UniformGrid Grid.Column="1" Columns="4">
                                        <StackPanel HorizontalAlignment="Center">
                                            <TextBlock x:Name="CPUBenchmarkScore" Text="--" FontSize="20" FontWeight="Bold" Foreground="{StaticResource SecondaryColor}" HorizontalAlignment="Center"/>
                                            <TextBlock Text="CPU" FontSize="12" Foreground="{StaticResource TextSecondary}" HorizontalAlignment="Center"/>
                                        </StackPanel>
                                        <StackPanel HorizontalAlignment="Center">
                                            <TextBlock x:Name="MemoryBenchmarkScore" Text="--" FontSize="20" FontWeight="Bold" Foreground="{StaticResource PrimaryColor}" HorizontalAlignment="Center"/>
                                            <TextBlock Text="Memory" FontSize="12" Foreground="{StaticResource TextSecondary}" HorizontalAlignment="Center"/>
                                        </StackPanel>
                                        <StackPanel HorizontalAlignment="Center">
                                            <TextBlock x:Name="DiskBenchmarkScore" Text="--" FontSize="20" FontWeight="Bold" Foreground="{StaticResource WarningColor}" HorizontalAlignment="Center"/>
                                            <TextBlock Text="Disk" FontSize="12" Foreground="{StaticResource TextSecondary}" HorizontalAlignment="Center"/>
                                        </StackPanel>
                                        <StackPanel HorizontalAlignment="Center">
                                            <TextBlock x:Name="NetworkBenchmarkScore" Text="--" FontSize="20" FontWeight="Bold" Foreground="{StaticResource InfoColor}" HorizontalAlignment="Center"/>
                                            <TextBlock Text="Network" FontSize="12" Foreground="{StaticResource TextSecondary}" HorizontalAlignment="Center"/>
                                        </StackPanel>
                                    </UniformGrid>
                                </Grid>
                            </Border>

                            <Border Grid.Row="2" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0" Margin="0,0,15,0">
                                        <TextBlock Text="System Information" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                        <TextBlock x:Name="BenchmarkCPUInfo" Text="CPU: --" FontSize="12" Foreground="{StaticResource TextSecondary}" Margin="0,3,0,0"/>
                                        <TextBlock x:Name="BenchmarkRAMInfo" Text="RAM: --" FontSize="12" Foreground="{StaticResource TextSecondary}" Margin="0,3,0,0"/>
                                        <TextBlock x:Name="BenchmarkDiskInfo" Text="Disk: --" FontSize="12" Foreground="{StaticResource TextSecondary}" Margin="0,3,0,0"/>
                                    </StackPanel>
                                    <StackPanel Grid.Column="1">
                                        <TextBlock Text="Detailed Results" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                        <ScrollViewer MaxHeight="150" Style="{StaticResource ModernScrollViewer}">
                                            <StackPanel x:Name="BenchmarkResultsPanel">
                                                <TextBlock Text="Run a benchmark to see detailed results." FontSize="12" Foreground="{StaticResource TextMuted}" FontStyle="Italic"/>
                                            </StackPanel>
                                        </ScrollViewer>
                                    </StackPanel>
                                </Grid>
                            </Border>

                            <Border Grid.Row="3" Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="Benchmark Progress" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <ProgressBar x:Name="BenchmarkProgressBar" Style="{StaticResource ModernProgressBar}" Height="20" Value="0" Maximum="100"/>
                                    <TextBlock x:Name="BenchmarkProgressText" Text="Ready to benchmark" FontSize="12" Foreground="{StaticResource TextSecondary}" Margin="0,5,0,0"/>
                                </StackPanel>
                            </Border>
                        </Grid>
                    </ScrollViewer>
                </TabItem>

                <!-- BATTERY TAB -->
                <TabItem Header="Battery" Style="{StaticResource MainTabItem}">
                    <ScrollViewer Style="{StaticResource ModernScrollViewer}" Padding="20">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <Border Grid.Row="0" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0" Orientation="Horizontal" Margin="0,0,30,0">
                                        <TextBlock x:Name="BatteryIcon" Text="[BAT]" FontSize="32" Foreground="{StaticResource SuccessColor}" VerticalAlignment="Center"/>
                                        <StackPanel Margin="15,0,0,0" VerticalAlignment="Center">
                                            <TextBlock x:Name="BatteryPercent" Text="--%" FontSize="36" FontWeight="Bold" Foreground="{StaticResource TextPrimary}"/>
                                            <TextBlock x:Name="BatteryStatus" Text="Status: --" FontSize="12" Foreground="{StaticResource TextSecondary}"/>
                                        </StackPanel>
                                    </StackPanel>
                                    <UniformGrid Grid.Column="1" Columns="3">
                                        <StackPanel HorizontalAlignment="Center">
                                            <TextBlock x:Name="BatteryHealth" Text="--%" FontSize="20" FontWeight="Bold" Foreground="{StaticResource SuccessColor}" HorizontalAlignment="Center"/>
                                            <TextBlock Text="Health" FontSize="12" Foreground="{StaticResource TextSecondary}" HorizontalAlignment="Center"/>
                                        </StackPanel>
                                        <StackPanel HorizontalAlignment="Center">
                                            <TextBlock x:Name="BatteryCycles" Text="--" FontSize="20" FontWeight="Bold" Foreground="{StaticResource PrimaryColor}" HorizontalAlignment="Center"/>
                                            <TextBlock Text="Cycles" FontSize="12" Foreground="{StaticResource TextSecondary}" HorizontalAlignment="Center"/>
                                        </StackPanel>
                                        <StackPanel HorizontalAlignment="Center">
                                            <TextBlock x:Name="BatteryTime" Text="--:--" FontSize="20" FontWeight="Bold" Foreground="{StaticResource InfoColor}" HorizontalAlignment="Center"/>
                                            <TextBlock Text="Remaining" FontSize="12" Foreground="{StaticResource TextSecondary}" HorizontalAlignment="Center"/>
                                        </StackPanel>
                                    </UniformGrid>
                                </Grid>
                            </Border>

                            <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel>
                                    <TextBlock Text="Power Plan" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <Grid>
                                        <StackPanel Orientation="Horizontal">
                                            <ComboBox x:Name="PowerPlanCombo" Width="200" Height="30" Background="{StaticResource SurfaceBg2}" Foreground="{StaticResource TextPrimary}" BorderBrush="{StaticResource BorderBrush}">
                                                <ComboBoxItem Content="Balanced"/>
                                                <ComboBoxItem Content="High Performance"/>
                                                <ComboBoxItem Content="Power Saver"/>
                                                <ComboBoxItem Content="Ultimate Performance"/>
                                            </ComboBox>
                                            <Button x:Name="ApplyPowerPlanBtn" Content="Apply" Style="{StaticResource ModernButton}" Margin="10,0,0,0" Width="80"/>
                                        </StackPanel>
                                    </Grid>
                                </StackPanel>
                            </Border>

                            <Border Grid.Row="2" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel>
                                    <TextBlock Text="Optimization Mode" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <Grid>
                                        <StackPanel Orientation="Horizontal">
                                            <Button x:Name="BatteryLifeModeBtn" Content="Max Battery Life" Style="{StaticResource SuccessButton}" Margin="0,0,10,0" Width="150"/>
                                            <Button x:Name="BalancedModeBtn" Content="Balanced" Style="{StaticResource ModernButton}" Margin="0,0,10,0" Width="120"/>
                                            <Button x:Name="PerformanceModeBtn" Content="Performance" Style="{StaticResource DangerButton}" Width="130"/>
                                        </StackPanel>
                                    </Grid>
                                </StackPanel>
                            </Border>

                            <Border Grid.Row="3" Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="Battery Tools" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <StackPanel Orientation="Horizontal">
                                        <Button x:Name="GenerateBatteryReportBtn" Content="Generate Battery Report" Style="{StaticResource SecondaryButton}" Margin="0,0,10,0"/>
                                        <Button x:Name="EnableBatterySaverBtn" Content="Enable Battery Saver" Style="{StaticResource SecondaryButton}"/>
                                    </StackPanel>
                                </StackPanel>
                            </Border>
                        </Grid>
                    </ScrollViewer>
                </TabItem>

                <!-- DNS TAB -->
                <TabItem Header="DNS" Style="{StaticResource MainTabItem}">
                    <ScrollViewer Style="{StaticResource ModernScrollViewer}" Padding="20">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>

                            <Border Grid.Row="0" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <Grid>
                                    <StackPanel Orientation="Horizontal">
                                        <Button x:Name="RunDNSBenchmarkBtn" Content="Benchmark DNS" Style="{StaticResource SuccessButton}" Margin="0,0,10,0" Width="140"/>
                                        <Button x:Name="AutoOptimizeDNSBtn" Content="Auto Optimize" Style="{StaticResource ModernButton}" Margin="0,0,10,0" Width="120"/>
                                        <Button x:Name="FlushDNSBtn" Content="Flush DNS Cache" Style="{StaticResource SecondaryButton}"/>
                                    </StackPanel>
                                </Grid>
                            </Border>

                            <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0">
                                        <TextBlock Text="Current DNS Servers" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                        <TextBlock x:Name="CurrentDNSPrimary" Text="Primary: --" FontSize="12" Foreground="{StaticResource TextSecondary}"/>
                                        <TextBlock x:Name="CurrentDNSSecondary" Text="Secondary: --" FontSize="12" Foreground="{StaticResource TextSecondary}"/>
                                    </StackPanel>
                                    <Button x:Name="ResetDNSBtn" Grid.Column="1" Content="Reset to DHCP" Style="{StaticResource SecondaryButton}" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>

                            <Border Grid.Row="2" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel>
                                    <TextBlock Text="Quick DNS Selection" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <WrapPanel>
                                        <Button x:Name="DNSCloudflareBtn" Content="Cloudflare (1.1.1.1)" Style="{StaticResource ModernButton}" Margin="0,0,8,8" MinWidth="140" Height="36"/>
                                        <Button x:Name="DNSGoogleBtn" Content="Google (8.8.8.8)" Style="{StaticResource ModernButton}" Margin="0,0,8,8" MinWidth="140" Height="36"/>
                                        <Button x:Name="DNSQuad9Btn" Content="Quad9 (9.9.9.9)" Style="{StaticResource ModernButton}" Margin="0,0,8,8" MinWidth="140" Height="36"/>
                                        <Button x:Name="DNSOpenDNSBtn" Content="OpenDNS" Style="{StaticResource ModernButton}" Margin="0,0,8,8" MinWidth="140" Height="36"/>
                                        <Button x:Name="DNSAdGuardBtn" Content="AdGuard DNS" Style="{StaticResource ModernButton}" Margin="0,0,8,8" MinWidth="140" Height="36"/>
                                        <Button x:Name="DNSNextDNSBtn" Content="NextDNS" Style="{StaticResource ModernButton}" Margin="0,0,8,8" MinWidth="140" Height="36"/>
                                        <Button x:Name="DNSControlDBtn" Content="Control D" Style="{StaticResource ModernButton}" Margin="0,0,8,8" MinWidth="140" Height="36"/>
                                        <Button x:Name="DNSDHCPBtn" Content="Reset to DHCP" Style="{StaticResource SecondaryButton}" Margin="0,0,8,8" MinWidth="140" Height="36"/>
                                    </WrapPanel>
                                </StackPanel>
                            </Border>

                            <Border Grid.Row="3" Style="{StaticResource Card}">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="*"/>
                                    </Grid.RowDefinitions>
                                    <TextBlock Grid.Row="0" Text="DNS Benchmark Results" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <ScrollViewer Grid.Row="1" Style="{StaticResource ModernScrollViewer}" MaxHeight="200">
                                        <StackPanel x:Name="DNSResultsPanel">
                                            <TextBlock Text="Run a DNS benchmark to see results." FontSize="12" Foreground="{StaticResource TextMuted}" FontStyle="Italic"/>
                                        </StackPanel>
                                    </ScrollViewer>
                                </Grid>
                            </Border>
                        </Grid>
                    </ScrollViewer>
                </TabItem>

                <!-- GAMING TAB -->
                <TabItem Header="Gaming" Style="{StaticResource MainTabItem}">
                    <ScrollViewer Style="{StaticResource ModernScrollViewer}" Padding="20">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <Border Grid.Row="0" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="0" Text="[GAME]" FontSize="24" Foreground="{StaticResource PrimaryColor}" VerticalAlignment="Center" Margin="0,0,15,0"/>
                                    <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                        <TextBlock Text="Windows Game Mode" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}"/>
                                        <TextBlock x:Name="GameModeStatus" Text="Status: --" FontSize="12" Foreground="{StaticResource TextSecondary}"/>
                                    </StackPanel>
                                    <Button x:Name="ToggleGameModeBtn" Grid.Column="2" Content="Enable" Style="{StaticResource SuccessButton}" VerticalAlignment="Center" Width="100"/>
                                </Grid>
                            </Border>

                            <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel>
                                    <TextBlock Text="Gaming Optimization" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <Grid>
                                        <StackPanel Orientation="Horizontal">
                                            <Button x:Name="QuickGamingOptBtn" Content="Quick Optimize" Style="{StaticResource SuccessButton}" Margin="0,0,10,0" Width="140"/>
                                            <Button x:Name="FullGamingOptBtn" Content="Full Optimization" Style="{StaticResource ModernButton}" Margin="0,0,10,0" Width="140"/>
                                            <Button x:Name="AggressiveGamingOptBtn" Content="Aggressive" Style="{StaticResource DangerButton}" Width="120"/>
                                        </StackPanel>
                                    </Grid>
                                </StackPanel>
                            </Border>

                            <Border Grid.Row="2" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel>
                                    <TextBlock Text="Gaming Features" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <Grid Margin="0,0,0,8">
                                        <TextBlock Text="Enable GPU Hardware Scheduling" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                        <CheckBox x:Name="EnableGPUSched" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right"/>
                                    </Grid>
                                    <Grid Margin="0,0,0,8">
                                        <TextBlock Text="Optimize Network for Gaming" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                        <CheckBox x:Name="EnableNetOpt" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right"/>
                                    </Grid>
                                    <Grid Margin="0,0,0,8">
                                        <TextBlock Text="Disable Game DVR Background Recording" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                        <CheckBox x:Name="DisableGameDVR" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/>
                                    </Grid>
                                    <Grid>
                                        <TextBlock Text="Set Ultimate Performance Power Plan" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                        <CheckBox x:Name="UltimatePowerPlan" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right"/>
                                    </Grid>
                                </StackPanel>
                            </Border>

                            <Border Grid.Row="3" Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="Game Cache Cleanup" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <StackPanel Orientation="Horizontal">
                                        <Button x:Name="ClearSteamCacheBtn" Content="Steam Cache" Style="{StaticResource SecondaryButton}" Margin="0,0,10,0"/>
                                        <Button x:Name="ClearEpicCacheBtn" Content="Epic Cache" Style="{StaticResource SecondaryButton}" Margin="0,0,10,0"/>
                                        <Button x:Name="ClearAllGameCacheBtn" Content="Clear All Game Caches" Style="{StaticResource ModernButton}"/>
                                    </StackPanel>
                                    <TextBlock x:Name="GameCacheFreed" Text="" FontSize="12" Foreground="{StaticResource SuccessColor}" Margin="0,10,0,0"/>
                                </StackPanel>
                            </Border>
                        </Grid>
                    </ScrollViewer>
                </TabItem>

                <!-- PRIVACY TAB -->
                <TabItem Header="Privacy" Style="{StaticResource MainTabItem}">
                    <ScrollViewer Style="{StaticResource ModernScrollViewer}" Padding="20">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <Border Grid.Row="0" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0" Orientation="Horizontal">
                                        <TextBlock Text="[LOCK]" FontSize="24" Foreground="{StaticResource PrimaryColor}" VerticalAlignment="Center" Margin="0,0,15,0"/>
                                        <StackPanel VerticalAlignment="Center">
                                            <TextBlock Text="Privacy Score" FontSize="14" Foreground="{StaticResource TextSecondary}"/>
                                            <TextBlock x:Name="PrivacyScoreText" Text="--" FontSize="32" FontWeight="Bold" Foreground="{StaticResource SuccessColor}"/>
                                        </StackPanel>
                                    </StackPanel>
                                    <Button x:Name="RunPrivacyScanBtn" Grid.Column="1" Content="Scan Privacy Settings" Style="{StaticResource ModernButton}" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>

                            <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel>
                                    <TextBlock Text="Telemetry Settings" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <Grid Margin="0,0,0,8">
                                        <TextBlock Text="Telemetry Level:" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                        <ComboBox x:Name="TelemetryLevelCombo" HorizontalAlignment="Right" Width="150" Height="28" Background="{StaticResource SurfaceBg2}" Foreground="{StaticResource TextPrimary}" BorderBrush="{StaticResource BorderBrush}">
                                            <ComboBoxItem Content="Disabled"/>
                                            <ComboBoxItem Content="Basic" IsSelected="True"/>
                                            <ComboBoxItem Content="Enhanced"/>
                                            <ComboBoxItem Content="Full"/>
                                        </ComboBox>
                                    </Grid>
                                    <Grid>
                                        <TextBlock Text="Disable Telemetry Service" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                        <CheckBox x:Name="DisableTelemetrySvc" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/>
                                    </Grid>
                                </StackPanel>
                            </Border>

                            <Border Grid.Row="2" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel>
                                    <TextBlock Text="Privacy Options" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <Grid Margin="0,0,0,8">
                                        <TextBlock Text="Disable Cortana" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                        <CheckBox x:Name="DisableCortanaCheck" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/>
                                    </Grid>
                                    <Grid Margin="0,0,0,8">
                                        <TextBlock Text="Disable Advertising ID" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                        <CheckBox x:Name="DisableAdIDCheck" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/>
                                    </Grid>
                                    <Grid Margin="0,0,0,8">
                                        <TextBlock Text="Disable Activity History" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                        <CheckBox x:Name="DisableActivityHistory" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/>
                                    </Grid>
                                    <Grid>
                                        <TextBlock Text="Disable Location Tracking" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                        <CheckBox x:Name="DisableLocationCheck" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/>
                                    </Grid>
                                </StackPanel>
                            </Border>

                            <Border Grid.Row="3" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel>
                                    <TextBlock Text="Quick Actions" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <StackPanel Orientation="Horizontal">
                                        <Button x:Name="ApplyPrivacyBasicBtn" Content="Basic Privacy" Style="{StaticResource ModernButton}" Margin="0,0,10,0"/>
                                        <Button x:Name="ApplyPrivacyStrictBtn" Content="Strict Privacy" Style="{StaticResource DangerButton}" Margin="0,0,10,0"/>
                                        <Button x:Name="ApplyPrivacySettingsBtn" Content="Apply Selected" Style="{StaticResource SuccessButton}"/>
                                    </StackPanel>
                                </StackPanel>
                            </Border>

                            <Border Grid.Row="4" Style="{StaticResource Card}">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="*"/>
                                    </Grid.RowDefinitions>
                                    <TextBlock Grid.Row="0" Text="Privacy Issues Found" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <ScrollViewer Grid.Row="1" Style="{StaticResource ModernScrollViewer}" MaxHeight="150">
                                        <StackPanel x:Name="PrivacyIssuesPanel">
                                            <TextBlock Text="Run a privacy scan to detect issues." FontSize="12" Foreground="{StaticResource TextMuted}" FontStyle="Italic"/>
                                        </StackPanel>
                                    </ScrollViewer>
                                </Grid>
                            </Border>
                        </Grid>
                    </ScrollViewer>
                </TabItem>

                <!-- STORAGE TAB -->
                <TabItem Header="Storage" Style="{StaticResource MainTabItem}">
                    <ScrollViewer Style="{StaticResource ModernScrollViewer}" Padding="20">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <Border Grid.Row="0" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0" Orientation="Horizontal" Margin="0,0,20,0">
                                        <TextBlock Text="[DISK]" FontSize="24" Foreground="{StaticResource InfoColor}" VerticalAlignment="Center" Margin="0,0,15,0"/>
                                        <StackPanel VerticalAlignment="Center">
                                            <TextBlock x:Name="StorageHealthScore" Text="--" FontSize="28" FontWeight="Bold" Foreground="{StaticResource SuccessColor}"/>
                                            <TextBlock Text="Storage Health" FontSize="12" Foreground="{StaticResource TextSecondary}"/>
                                        </StackPanel>
                                    </StackPanel>
                                    <Button x:Name="RunStorageScanBtn" Grid.Column="1" Content="Scan Storage Health" Style="{StaticResource ModernButton}" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>

                            <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="*"/>
                                    </Grid.RowDefinitions>
                                    <TextBlock Grid.Row="0" Text="Disks" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <ScrollViewer Grid.Row="1" Style="{StaticResource ModernScrollViewer}" MaxHeight="150">
                                        <StackPanel x:Name="DiskListPanel">
                                            <TextBlock Text="Scanning disks..." FontSize="12" Foreground="{StaticResource TextMuted}" FontStyle="Italic"/>
                                        </StackPanel>
                                    </ScrollViewer>
                                </Grid>
                            </Border>

                            <Border Grid.Row="2" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel>
                                    <TextBlock Text="SSD Optimization" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <Grid Margin="0,0,0,8">
                                        <TextBlock Text="TRIM Status:" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                        <TextBlock x:Name="TRIMStatus" Text="--" FontSize="13" Foreground="{StaticResource SuccessColor}" HorizontalAlignment="Right"/>
                                    </Grid>
                                    <StackPanel Orientation="Horizontal">
                                        <Button x:Name="EnableTRIMBtn" Content="Enable TRIM" Style="{StaticResource ModernButton}" Margin="0,0,10,0"/>
                                        <Button x:Name="RunTRIMBtn" Content="Run TRIM Now" Style="{StaticResource SuccessButton}"/>
                                    </StackPanel>
                                </StackPanel>
                            </Border>

                            <Border Grid.Row="3" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel>
                                    <TextBlock Text="Storage Sense" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <Grid Margin="0,0,0,8">
                                        <TextBlock Text="Enable Storage Sense (Auto Cleanup)" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                        <CheckBox x:Name="EnableStorageSenseCheck" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right"/>
                                    </Grid>
                                    <Grid>
                                        <TextBlock Text="Clean Recycle Bin Automatically" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                        <CheckBox x:Name="AutoCleanRecycleCheck" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right"/>
                                    </Grid>
                                </StackPanel>
                            </Border>

                            <Border Grid.Row="4" Style="{StaticResource Card}">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="*"/>
                                    </Grid.RowDefinitions>
                                    <TextBlock Grid.Row="0" Text="Health Warnings" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <ScrollViewer Grid.Row="1" Style="{StaticResource ModernScrollViewer}" MaxHeight="100">
                                        <StackPanel x:Name="StorageWarningsPanel">
                                            <TextBlock Text="No warnings. Storage is healthy." FontSize="12" Foreground="{StaticResource SuccessColor}"/>
                                        </StackPanel>
                                    </ScrollViewer>
                                </Grid>
                            </Border>
                        </Grid>
                    </ScrollViewer>
                </TabItem>
                <TabItem Header="Tweaks" Style="{StaticResource MainTabItem}">
                    <ScrollViewer Style="{StaticResource ModernScrollViewer}" Padding="20">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <!-- Privacy and Telemetry -->
                            <Border Grid.Row="0" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel>
                                    <TextBlock Text="Privacy &amp; Telemetry" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Disable Telemetry Service (DiagTrack)" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaDiagTrack" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Minimal Diagnostic Data Collection" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaDiagData" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Disable Windows Error Reporting" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaErrorReport" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Set Feedback Frequency to Never" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaFeedback" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Disable Advertising ID" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaAdvertID" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Disable Tailored Experiences" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaTailored" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Disable Bing Search in Start Menu" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaBingSearch" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Disable Silent App Suggestions Install" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaSilentApps" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Hide Suggested Content in Settings" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaSettingsSugg" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Hide Windows Welcome Experience" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaWinWelcome" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Disable Sign-in Info Reuse After Update" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaSigninInfo" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="False"/></Grid>
                                    <Grid><TextBlock Text="Disable Diagnostic Scheduled Tasks" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaSchedTasks" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="False"/></Grid>
                                </StackPanel>
                            </Border>

                            <!-- UI and File Explorer -->
                            <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel>
                                    <TextBlock Text="UI &amp; File Explorer" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Show Hidden Files and Folders" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaHiddenItems" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Show File Name Extensions" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaFileExt" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Hide OneDrive Sync Ad in Explorer" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaOneDriveAd" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Remove Shortcut Text Suffix" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaShortcutSuffix" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Show Folder Merge Conflicts" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaMergeConflicts" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Detailed File Transfer Dialog" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaFileTransfer" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="False"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Open File Explorer to This PC" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaExplorerPC" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="False"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Show Seconds in System Clock" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaClockSeconds" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="False"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Expand File Explorer Ribbon" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaExplorerRibbon" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="False"/></Grid>
                                    <Grid><TextBlock Text="Disable Snap Assist" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaSnapAssist" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="False"/></Grid>
                                </StackPanel>
                            </Border>

                            <!-- Taskbar and System -->
                            <Border Grid.Row="2" Style="{StaticResource Card}" Margin="0,0,0,15">
                                <StackPanel>
                                    <TextBlock Text="Taskbar &amp; System" FontSize="14" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Hide Cortana Button from Taskbar" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaCortana" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Disable News and Interests on Taskbar" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaNews" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Hide Meet Now from Taskbar" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaMeetNow" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Hide Search Highlights" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaSearchHL" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Disable F1 Help Key" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaF1Key" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Disable Autoplay for Removable Drives" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaAutoplay" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Disable Xbox Game Tips" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaXboxTips" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="True"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Hide Task View Button from Taskbar" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaTaskView" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="False"/></Grid>
                                    <Grid Margin="0,0,0,6"><TextBlock Text="Disable Xbox Game Bar" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaXboxBar" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="False"/></Grid>
                                    <Grid><TextBlock Text="Enable NumLock at Startup" FontSize="13" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/><CheckBox x:Name="SophiaNumLock" Style="{StaticResource ModernCheckBox}" HorizontalAlignment="Right" IsChecked="False"/></Grid>
                                </StackPanel>
                            </Border>

                            <!-- Action Buttons -->
                            <Border Grid.Row="3" Style="{StaticResource Card}">
                                <StackPanel>
                                    <TextBlock Text="Powered by Sophia Script for Windows 10 v6.1.4  -  github.com/farag2/Sophia-Script-for-Windows" FontSize="11" Foreground="{StaticResource TextMuted}" Margin="0,0,0,12" FontStyle="Italic"/>
                                    <StackPanel Orientation="Horizontal">
                                        <Button x:Name="ApplySophiaTweaksBtn" Content="Apply Selected Tweaks" Style="{StaticResource SuccessButton}" Margin="0,0,10,0" Padding="15,8"/>
                                        <Button x:Name="ApplyAllSophiaTweaksBtn" Content="Apply All Tweaks" Style="{StaticResource ModernButton}" Padding="15,8"/>
                                    </StackPanel>
                                </StackPanel>
                            </Border>

                        </Grid>
                    </ScrollViewer>
                </TabItem>

                <!-- MAINTENANCE TAB -->
                <TabItem Header="Maintenance" Style="{StaticResource MainTabItem}">
                    <Grid Margin="20">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- Info / Status Card -->
                        <Border Grid.Row="0" Style="{StaticResource Card}" Margin="0,0,0,15">
                            <StackPanel>
                                <TextBlock Text="Printer Maintenance" FontSize="18" FontWeight="Bold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,8"/>
                                <TextBlock TextWrapping="Wrap" FontSize="13" Foreground="{StaticResource TextSecondary}"
                                    Text="Fixes common printer errors including error 0x00000709. Stops the Print Spooler, clears print job queues and caches, repairs registry settings, and restarts all printing services."/>
                                <Separator Background="{StaticResource BorderBrush}" Margin="0,12,0,12"/>
                                <StackPanel Orientation="Horizontal">
                                    <Ellipse x:Name="PrinterStatusLight" Width="14" Height="14" Fill="Gray" Margin="0,0,8,0" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="PrinterTaskLabel" Text="Ready - click Fix Printers to begin" FontSize="13" Foreground="{StaticResource TextSecondary}" VerticalAlignment="Center"/>
                                </StackPanel>
                            </StackPanel>
                        </Border>

                        <!-- Output and Progress Card -->
                        <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,0,0,15">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="*"/>
                                    <RowDefinition Height="Auto"/>
                                </Grid.RowDefinitions>
                                <TextBox Grid.Row="0" x:Name="PrinterOutputBox"
                                    Background="#0A0A14" Foreground="#90EE90"
                                    FontFamily="Consolas" FontSize="11"
                                    BorderThickness="1" BorderBrush="{StaticResource BorderBrush}"
                                    IsReadOnly="True" AcceptsReturn="True"
                                    VerticalScrollBarVisibility="Auto"
                                    HorizontalScrollBarVisibility="Disabled"
                                    TextWrapping="Wrap" Padding="10" MinHeight="220"/>
                                <ProgressBar Grid.Row="1" x:Name="PrinterProgressBar"
                                    Style="{StaticResource ModernProgressBar}"
                                    Height="12" Margin="0,10,0,0" Value="0" Maximum="10"/>
                            </Grid>
                        </Border>

                        <!-- Controls Card -->
                        <Border Grid.Row="2" Style="{StaticResource Card}">
                            <StackPanel>
                                <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                                    <Button x:Name="PrinterFixBtn"    Content="Fix Printers" Style="{StaticResource SuccessButton}"   Padding="20,8" Margin="0,0,10,0"/>
                                    <Button x:Name="PrinterStopBtn"   Content="Stop"         Style="{StaticResource ModernButton}"    Padding="15,8" Margin="0,0,10,0"/>
                                    <Button x:Name="PrinterPauseBtn"  Content="Pause"        Style="{StaticResource SecondaryButton}" Padding="15,8" Margin="0,0,10,0"/>
                                    <Button x:Name="PrinterResumeBtn" Content="Resume"       Style="{StaticResource SecondaryButton}" Padding="15,8"/>
                                </StackPanel>
                                <TextBlock FontSize="11" Foreground="{StaticResource TextMuted}"
                                    Text="Log file: %SystemRoot%\Temp\PrinterFix.log  |  Author: Simon Peter  |  Version 4.4"/>
                            </StackPanel>
                        </Border>
                    </Grid>
                </TabItem>

                <TabItem Header="TronScript" Style="{StaticResource MainTabItem}">
                    <Grid Margin="20">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- Detection Card -->
                        <Border Grid.Row="0" Style="{StaticResource Card}" Margin="0,0,0,15">
                            <StackPanel>
                                <TextBlock Text="TronScript - Full System Maintenance Suite" FontSize="18" FontWeight="Bold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,6"/>
                                <TextBlock TextWrapping="Wrap" FontSize="13" Foreground="{StaticResource TextSecondary}" Margin="0,0,0,12"
                                    Text="TronScript automates over 100 Windows repair and maintenance tasks across 8 stages: Prep, TempClean, De-Bloat, Disinfect, Repair, Patch, Optimize, and Wrap-up. Place tron.bat in Modules\TronScript\tron\ or use Browse to locate it."/>
                                <Separator Background="{StaticResource BorderBrush}" Margin="0,0,0,12"/>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                                        <Ellipse x:Name="TronDetectLight" Width="12" Height="12" Fill="OrangeRed" Margin="0,0,8,0" VerticalAlignment="Center"/>
                                        <TextBlock x:Name="TronDetectLabel" Text="Checking..." FontSize="12" Foreground="{StaticResource TextSecondary}" VerticalAlignment="Center" Margin="0,0,16,0"/>
                                        <TextBlock x:Name="TronPathText" Text="" FontSize="11" Foreground="{StaticResource TextMuted}" VerticalAlignment="Center" FontFamily="Consolas" TextTrimming="CharacterEllipsis"/>
                                    </StackPanel>
                                    <Button Grid.Column="1" x:Name="TronBrowseBtn" Content="Browse..." Style="{StaticResource SecondaryButton}" Padding="14,6" VerticalAlignment="Center"/>
                                </Grid>
                            </StackPanel>
                        </Border>

                        <!-- Options Card -->
                        <Border Grid.Row="1" Style="{StaticResource Card}" Margin="0,0,0,15">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>

                                <!-- Stage Skips -->
                                <StackPanel Grid.Column="0" Margin="0,0,20,0">
                                    <TextBlock Text="Skip Stages" FontSize="13" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <CheckBox x:Name="TronSkipDebloat"      Content="Skip De-Bloat (-sdb)"           Foreground="{StaticResource TextSecondary}" Margin="0,4,0,0"/>
                                    <CheckBox x:Name="TronSkipAntiMalware"  Content="Skip All Anti-Malware (-sa)"    Foreground="{StaticResource TextSecondary}" Margin="0,4,0,0"/>
                                    <CheckBox x:Name="TronSkipDefrag"       Content="Skip Defrag (-sd)"              Foreground="{StaticResource TextSecondary}" Margin="0,4,0,0"/>
                                    <CheckBox x:Name="TronSkipPatches"      Content="Skip All Patches (-sp)"         Foreground="{StaticResource TextSecondary}" Margin="0,4,0,0"/>
                                    <CheckBox x:Name="TronSkipTelemetry"    Content="Skip Telemetry Removal (-str)"  Foreground="{StaticResource TextSecondary}" Margin="0,4,0,0"/>
                                    <CheckBox x:Name="TronSkipNetworkReset" Content="Skip Network Reset (-snr)"      Foreground="{StaticResource TextSecondary}" Margin="0,4,0,0"/>
                                </StackPanel>

                                <!-- Run Options -->
                                <StackPanel Grid.Column="1">
                                    <TextBlock Text="Run Options" FontSize="13" FontWeight="SemiBold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                                    <CheckBox x:Name="TronAutoMode"       Content="Auto Mode - no prompts (-a)"    Foreground="{StaticResource TextSecondary}" Margin="0,4,0,0"/>
                                    <CheckBox x:Name="TronVerbose"        Content="Verbose output (-v)"            Foreground="{StaticResource TextSecondary}" Margin="0,4,0,0"/>
                                    <CheckBox x:Name="TronSkipEventLogs"  Content="Skip Event Log clearing (-se)"  Foreground="{StaticResource TextSecondary}" Margin="0,4,0,0"/>
                                    <CheckBox x:Name="TronRebootAfter"    Content="Reboot after completion (-r)"   Foreground="{StaticResource TextSecondary}" Margin="0,4,0,0"/>
                                    <CheckBox x:Name="TronSelfDestruct"   Content="Self-destruct after run (-x)"   Foreground="OrangeRed" Margin="0,4,0,0"/>
                                </StackPanel>
                            </Grid>
                        </Border>

                        <!-- Live Log Card -->
                        <Border Grid.Row="2" Style="{StaticResource Card}" Margin="0,0,0,15">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="*"/>
                                    <RowDefinition Height="Auto"/>
                                </Grid.RowDefinitions>
                                <TextBox Grid.Row="0" x:Name="TronOutputBox"
                                    Background="#0A0A14" Foreground="#90EE90"
                                    FontFamily="Consolas" FontSize="11"
                                    BorderThickness="1" BorderBrush="{StaticResource BorderBrush}"
                                    IsReadOnly="True" AcceptsReturn="True"
                                    VerticalScrollBarVisibility="Auto"
                                    HorizontalScrollBarVisibility="Disabled"
                                    TextWrapping="Wrap" Padding="10" MinHeight="200"/>
                                <ProgressBar Grid.Row="1" x:Name="TronProgressBar"
                                    Style="{StaticResource ModernProgressBar}"
                                    Height="12" Margin="0,10,0,0" Value="0" Maximum="8"/>
                            </Grid>
                        </Border>

                        <!-- Controls Card -->
                        <Border Grid.Row="3" Style="{StaticResource Card}">
                            <StackPanel>
                                <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                                    <Button x:Name="TronRunBtn"  Content="Run TronScript" Style="{StaticResource SuccessButton}"  Padding="20,8" Margin="0,0,10,0" IsEnabled="False"/>
                                    <Button x:Name="TronStopBtn" Content="Stop"           Style="{StaticResource ModernButton}"   Padding="15,8" IsEnabled="False"/>
                                </StackPanel>
                                <TextBlock FontSize="11" Foreground="{StaticResource TextMuted}"
                                    Text="TronScript by vocatus  |  Log: %SystemDrive%\logs\tron\  |  Place tron.bat in: Modules\TronScript\tron\tron.bat"/>
                            </StackPanel>
                        </Border>
                    </Grid>
                </TabItem>
            </TabControl>
        </Grid>

        <!-- Status Bar -->
        <Border Grid.Row="2" Background="{StaticResource SurfaceBg}" CornerRadius="0,0,10,10">
            <Grid Margin="20,0">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <Ellipse x:Name="StatusIndicator" Width="10" Height="10" Fill="{StaticResource SuccessColor}" Margin="0,0,10,0"/>
                    <TextBlock x:Name="StatusText" Text="Ready" FontSize="12" Foreground="{StaticResource TextSecondary}"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                    <TextBlock x:Name="SessionIdText" Text="Session: --" FontSize="11" Foreground="{StaticResource TextMuted}" Margin="0,0,20,0"/>
                    <TextBlock x:Name="TimeText" Text="--:--:--" FontSize="11" Foreground="{StaticResource TextMuted}"/>
                </StackPanel>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

    # Create XML reader and load XAML
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $script:UIMainWindow = [Windows.Markup.XamlReader]::Load($reader)

    # Store reference in AppCore
    Set-UIWindow $script:UIMainWindow

    # Allow dragging from the title bar area
    try {
        $script:UIMainWindow.MouseLeftButtonDown.Add({
            $window = $script:UIMainWindow
            try { $window.DragMove() } catch {}
        }.GetNewClosure())
    } catch { }

    return $script:UIMainWindow
}

# Function to find element by name
function global:Find-UIElement {
    param([string]$Name)
    
    $window = Get-UIWindow
    if ($window) {
        return $window.FindName($Name)
    }
    return $null
}

# Function to update status bar
function global:Update-Status {
    param(
        [string]$Text,
        [ValidateSet("Ready", "Working", "Error", "Success")]
        [string]$State = "Ready"
    )
    
    $statusText = Find-UIElement "StatusText"
    $statusIndicator = Find-UIElement "StatusIndicator"
    
    if ($statusText) {
        $statusText.Text = $Text
    }
    
    if ($statusIndicator) {
        switch ($State) {
            "Ready" { $statusIndicator.Fill = [System.Windows.Media.Brushes]::LimeGreen }
            "Working" { $statusIndicator.Fill = [System.Windows.Media.Brushes]::Gold }
            "Error" { $statusIndicator.Fill = [System.Windows.Media.Brushes]::OrangeRed }
            "Success" { $statusIndicator.Fill = [System.Windows.Media.Brushes]::LimeGreen }
        }
    }
}

# Function to switch theme
function global:Switch-Theme {
    param([string]$Theme = "Dark")
    
    $window = Get-UIWindow
    if (-not $window) { return }
    
    try {
        if ($Theme -eq "Dark") {
            # Dark theme colors
            $window.Background = "#1F2937"
            Set-ConfigValue "Theme" "Dark"
        } else {
            # Light theme colors
            $window.Background = "#F5F7FA"
            Set-ConfigValue "Theme" "Light"
        }
        Save-Settings
    } catch {
        Write-Log -Level "WARNING" -Category "UI" -Message "Failed to switch theme: $($_.Exception.Message)"
    }
}

# Function to handle theme combo selection (called from code)
function global:ThemeCombo_SelectionChanged {
    param($sender, $e)
    
    # Try both possible names
    $themeCombo = Find-UIElement "SettingTheme"
    if (-not $themeCombo) { $themeCombo = Find-UIElement "SettingThemeSelect" }
    
    if ($themeCombo -and $themeCombo.SelectedItem) {
        $selectedTheme = $themeCombo.SelectedItem.Content
        Switch-Theme -Theme $selectedTheme
    }
}

# Internal handler for programmatic binding
function global:ThemeCombo-SelectionChangedInternal {
    ThemeCombo_SelectionChanged
}

# Function to add activity log entry
function global:Add-ActivityLog {
    param([string]$Message)
    
    $activityLog = Find-UIElement "ActivityLog"
    
    if ($activityLog) {
        # Clear placeholder text if present
        if ($activityLog.Children.Count -eq 1) {
            $firstChild = $activityLog.Children[0]
            if ($firstChild -is [System.Windows.Controls.TextBlock] -and $firstChild.FontStyle -eq "Italic") {
                $activityLog.Children.Clear()
            }
        }
        
        $entry = New-Object System.Windows.Controls.TextBlock
        $entry.Text = "[$(Get-Date -Format 'HH:mm:ss')] $Message"
        $entry.FontSize = 13
        $entry.Foreground = [System.Windows.Media.Brushes]::Gray
        $entry.Margin = "0,2"
        
        $activityLog.Children.Insert(0, $entry)
        
        # Limit entries
        while ($activityLog.Children.Count -gt 50) {
            $activityLog.Children.RemoveAt($activityLog.Children.Count - 1)
        }
    }
}

# Function to update dashboard statistics
function global:Update-DashboardStats {
    # Get system info
    $systemInfo = Get-SystemInfo
    $diskInfo = Get-DiskInfo
    
    # Update health score
    $healthScoreResult = Get-SystemHealthScore
    $healthScore = $healthScoreResult.TotalScore
    $healthScoreText = Find-UIElement "HealthScoreText"
    $healthRatingText = Find-UIElement "HealthRatingText"
    $healthCircle = Find-UIElement "HealthCircle"
    
    if ($healthScoreText) { $healthScoreText.Text = "$healthScore/100" }
    if ($healthRatingText) {
        if ($healthScore -ge 80) {
            $healthRatingText.Text = "Excellent"
            $healthRatingText.Foreground = "#16A34A"
        } elseif ($healthScore -ge 60) {
            $healthRatingText.Text = "Good"
            $healthRatingText.Foreground = "#2563EB"
        } elseif ($healthScore -ge 40) {
            $healthRatingText.Text = "Fair"
            $healthRatingText.Foreground = "#D97706"
        } else {
            $healthRatingText.Text = "Poor"
            $healthRatingText.Foreground = "#DC2626"
        }
    }
    
    # Update circle (440 is circumference)
    if ($healthCircle) {
        $dash = ($healthScore / 100) * 440
        $dc = New-Object System.Windows.Media.DoubleCollection
        $dc.Add([double]$dash) | Out-Null
        $dc.Add([double]440) | Out-Null
        $healthCircle.StrokeDashArray = $dc
    }
    
    # Update stats
    $statServices = Find-UIElement "StatServices"
    $statStartup = Find-UIElement "StatStartup"
    
    if ($statServices) { $statServices.Text = (Get-RunningServicesCount) }
    if ($statStartup) { $statStartup.Text = (Get-StartupItemsCount) }
    
    # Update memory
    $memoryPercent = Find-UIElement "MemoryPercent"
    $memoryTotal = Find-UIElement "MemoryTotal"
    $memoryAvailable = Find-UIElement "MemoryAvailable"
    $memoryUsed = Find-UIElement "MemoryUsed"
    $memoryBar = Find-UIElement "MemoryBar"
    
    if ($memoryPercent) { $memoryPercent.Text = "$($systemInfo.MemoryPercent)%" }
    if ($memoryTotal) { $memoryTotal.Text = "$($systemInfo.TotalMemory) GB" }
    if ($memoryAvailable) { $memoryAvailable.Text = "$($systemInfo.FreeMemory) GB" }
    if ($memoryUsed) { $memoryUsed.Text = "$($systemInfo.UsedMemory) GB" }
    if ($memoryBar) { $memoryBar.Height = ($systemInfo.MemoryPercent / 100) * 80 }
    
    # Update CPU
    $cpuPercent = Find-UIElement "CPUPercent"
    $cpuCores = Find-UIElement "CPUCores"
    $cpuThreads = Find-UIElement "CPUThreads"
    $processCount = Find-UIElement "ProcessCount"
    $cpuBar = Find-UIElement "CPUBar"
    
    $cpuUsage = Get-CPUUsage
    
    if ($cpuPercent) { $cpuPercent.Text = "$cpuUsage%" }
    if ($cpuCores) { $cpuCores.Text = $systemInfo.CPUCores }
    if ($cpuThreads) { $cpuThreads.Text = $systemInfo.CPUThreads }
    if ($processCount) { $processCount.Text = (Get-ProcessCount) }
    if ($cpuBar) { $cpuBar.Height = ($cpuUsage / 100) * 80 }
    
    # Update disk usage panel
    $diskUsagePanel = Find-UIElement "DiskUsagePanel"
    if ($diskUsagePanel) {
        $diskUsagePanel.Children.Clear()
        
        foreach ($disk in $diskInfo) {
            $grid = New-Object System.Windows.Controls.Grid
            $grid.Margin = "0,0,0,10"
            
            $col1 = New-Object System.Windows.Controls.ColumnDefinition
            $col1.Width = "50"
            $col2 = New-Object System.Windows.Controls.ColumnDefinition
            $col2.Width = "*"
            $col3 = New-Object System.Windows.Controls.ColumnDefinition
            $col3.Width = "Auto"
            
            $grid.ColumnDefinitions.Add($col1) | Out-Null
            $grid.ColumnDefinitions.Add($col2) | Out-Null
            $grid.ColumnDefinitions.Add($col3) | Out-Null
            
            # Drive label
            $label = New-Object System.Windows.Controls.TextBlock
            $label.Text = "$($disk.Drive)"
            $label.FontSize = 14
            $label.FontWeight = [System.Windows.FontWeights]::SemiBold
            $label.VerticalAlignment = "Center"
            $label.Foreground = "#111827"
            [System.Windows.Controls.Grid]::SetColumn($label, 0)
            $grid.Children.Add($label) | Out-Null
            
            # Progress bar
            $progress = New-Object System.Windows.Controls.ProgressBar
            $progress.Style = $script:UIMainWindow.FindResource("ModernProgressBar")
            $progress.Value = $disk.PercentUsed
            $progress.Maximum = 100
            $progress.VerticalAlignment = "Center"
            $progress.Height = 20
            [System.Windows.Controls.Grid]::SetColumn($progress, 1)
            $grid.Children.Add($progress) | Out-Null
            
            # Size text
            $sizeText = New-Object System.Windows.Controls.TextBlock
            $sizeText.Text = "$($disk.Free) GB free of $($disk.Total) GB"
            $sizeText.FontSize = 12
            $sizeText.VerticalAlignment = "Center"
            $sizeText.Foreground = [System.Windows.Media.Brushes]::Gray
            $sizeText.Margin = "10,0,0,0"
            [System.Windows.Controls.Grid]::SetColumn($sizeText, 2)
            $grid.Children.Add($sizeText) | Out-Null
            
            $diskUsagePanel.Children.Add($grid) | Out-Null
        }
    }
    
    # Update time
    $timeText = Find-UIElement "TimeText"
    if ($timeText) { $timeText.Text = Get-Date -Format "HH:mm:ss" }
    
    # Update session ID
    $sessionIdText = Find-UIElement "SessionIdText"
    if ($sessionIdText) { $sessionIdText.Text = "Session: $(Get-SessionId)" }
}

# Function for real-time monitoring updates (lightweight, fast)
function global:Update-RealtimeStats {
    try {
        # Update memory stats
        $memoryPercent = Find-UIElement "MemoryPercent"
        $memoryAvailable = Find-UIElement "MemoryAvailable"
        $memoryUsed = Find-UIElement "MemoryUsed"
        $memoryBar = Find-UIElement "MemoryBar"
        
        $memInfo = Get-CimInstance Win32_OperatingSystem
        $totalMemGB = [math]::Round($memInfo.TotalVisibleMemorySize / 1MB, 1)
        $freeMemGB = [math]::Round($memInfo.FreePhysicalMemory / 1MB, 1)
        $usedMemGB = [math]::Round($totalMemGB - $freeMemGB, 1)
        $memPercent = [math]::Round(($usedMemGB / $totalMemGB) * 100, 0)
        
        if ($memoryPercent) { $memoryPercent.Text = "$memPercent%" }
        if ($memoryAvailable) { $memoryAvailable.Text = "$freeMemGB GB" }
        if ($memoryUsed) { $memoryUsed.Text = "$usedMemGB GB" }
        if ($memoryBar) { 
            $newHeight = ($memPercent / 100) * 80
            if ($newHeight -gt 0) { $memoryBar.Height = $newHeight }
        }
        
        # Update CPU usage
        $cpuPercent = Find-UIElement "CPUPercent"
        $cpuBar = Find-UIElement "CPUBar"
        
        $cpuUsage = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        if ($cpuUsage -eq $null) { $cpuUsage = 0 }
        
        if ($cpuPercent) { $cpuPercent.Text = "$([math]::Round($cpuUsage, 0))%" }
        if ($cpuBar) {
            $cpuHeight = ($cpuUsage / 100) * 80
            if ($cpuHeight -gt 0) { $cpuBar.Height = $cpuHeight }
        }
        
        # Update process count
        $processCount = Find-UIElement "ProcessCount"
        if ($processCount) { $processCount.Text = (Get-Process).Count }
        
    } catch { }
}

# Function to toggle monitoring on/off
function global:Enable-Monitoring {
    $script:MonitoringEnabled = $true
}

function global:Disable-Monitoring {
    $script:MonitoringEnabled = $false
}

# Function to bind window control buttons
function global:Bind-WindowControls {
    $minimizeBtn = Find-UIElement "MinimizeBtn"
    $maximizeBtn = Find-UIElement "MaximizeBtn"
    $closeBtn = Find-UIElement "CloseBtn"
    
    $window = Get-UIWindow
    
    if ($minimizeBtn) {
        $minimizeBtn.Add_Click({
            $window.WindowState = "Minimized"
        }.GetNewClosure())
    }
    
    if ($maximizeBtn) {
        $maximizeBtn.Add_Click({
            if ($window.WindowState -eq "Maximized") {
                $window.WindowState = "Normal"
            } else {
                $window.WindowState = "Maximized"
            }
        }.GetNewClosure())
    }
    
    if ($closeBtn) {
        $closeBtn.Add_Click({
            $window.Close()
        }.GetNewClosure())
    }
}

# Function to update admin badge
function global:Update-AdminBadge {
    $adminBadge = Find-UIElement "AdminBadge"
    $adminText = Find-UIElement "AdminText"
    
    if (Get-AdminStatus) {
        if ($adminBadge) { $adminBadge.Background = "#16A34A" }
        if ($adminText) { $adminText.Text = "ADMIN" }
    } else {
        if ($adminBadge) { $adminBadge.Background = "#DC2626" }
        if ($adminText) { $adminText.Text = "[USER]" }
    }
}

# Function to update Test Mode badge
function global:Update-TestModeBadge {
    $testModeBadge = Find-UIElement "TestModeBadge"
    $testMode = Get-ConfigValue "TestMode"
    
    if ($testModeBadge) {
        if ($testMode -eq $true) {
            $testModeBadge.Visibility = "Visible"
        } else {
            $testModeBadge.Visibility = "Collapsed"
        }
    }
}

# Function to update settings tab
function global:Update-SettingsTab {
    $psVersionText = Find-UIElement "PSVersionText"
    if ($psVersionText) {
        $psVersionText.Text = $PSVersionTable.PSVersion.ToString()
    }
}


