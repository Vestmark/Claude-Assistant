<#
.SYNOPSIS
    Claude Code Assistant - GUI Application
.DESCRIPTION
    Installs and configures Claude Code with AWS Bedrock support.
    Designed to run without administrator privileges.
    - Checks prerequisite tools (Git, AWS CLI, Claude Code)
    - Installs Claude Code via official installer (claude.ai)
    - Configures environment variables at User scope
    - Provides model selection dropdowns for Bedrock
.NOTES
    Version: 1.0.0
    GitHub: https://github.com/Vestmark/Claude-Assistant
#>

# ============================================================
# Script Version & Update Configuration
# ============================================================
$script:ScriptVersion = "1.0.0"
$script:GitHubRawUrl = "https://raw.githubusercontent.com/Vestmark/Claude-Assistant/main/Claude%20Code%20Assistant%20(Windows).ps1"
$script:ScriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }

# Single combined C# compilation for all P/Invoke (console minimize + env broadcast)
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class NativeHelper {
    [DllImport("user32.dll")]   public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
        uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
}
'@ -ErrorAction SilentlyContinue

# Minimize the PowerShell console window so only the GUI is visible
[void][NativeHelper]::ShowWindow([NativeHelper]::GetConsoleWindow(), 6)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ============================================================
# XAML UI Definition
# ============================================================
[xml]$xaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Claude Code Assistant"
    Width="982" Height="750"
    WindowStartupLocation="CenterScreen"
    Background="#f3f4f6"
    FontFamily="Segoe UI" FontSize="13"
    ResizeMode="CanResizeWithGrip">

    <Window.Resources>
        <Style x:Key="PrimaryBtn" TargetType="Button">
            <Setter Property="Background" Value="#4f46e5"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Padding" Value="20,10"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Name="Bd" Background="{TemplateBinding Background}"
                                CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#4338ca"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="Bd" Property="Background" Value="#c7d2fe"/>
                                <Setter Property="Foreground" Value="#818cf8"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="SecondaryBtn" TargetType="Button">
            <Setter Property="Background" Value="#e5e7eb"/>
            <Setter Property="Foreground" Value="#374151"/>
            <Setter Property="Padding" Value="20,10"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Name="Bd" Background="{TemplateBinding Background}"
                                CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#d1d5db"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="Bd" Property="Background" Value="#f3f4f6"/>
                                <Setter Property="Foreground" Value="#9ca3af"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="DangerBtn" TargetType="Button">
            <Setter Property="Background" Value="#ef4444"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Padding" Value="20,10"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Name="Bd" Background="{TemplateBinding Background}"
                                CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#dc2626"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="CardBorder" TargetType="Border">
            <Setter Property="Background" Value="White"/>
            <Setter Property="CornerRadius" Value="8"/>
            <Setter Property="Padding" Value="20"/>
            <Setter Property="Margin" Value="0,0,0,12"/>
            <Setter Property="BorderBrush" Value="#e5e7eb"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>

        <Style x:Key="SectionTitle" TargetType="TextBlock">
            <Setter Property="FontSize" Value="16"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Foreground" Value="#1e293b"/>
            <Setter Property="Margin" Value="0,0,0,12"/>
        </Style>

        <Style x:Key="FormLabel" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#374151"/>
            <Setter Property="FontWeight" Value="Medium"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
            <Setter Property="Margin" Value="0,0,0,0"/>
        </Style>
    </Window.Resources>

    <DockPanel Margin="20">
        <!-- Header -->
        <StackPanel DockPanel.Dock="Top" Margin="0,0,0,16">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0">
                    <TextBlock Text="Claude Code Assistant"
                               FontSize="22" FontWeight="Bold" Foreground="#1e293b"/>
                    <TextBlock Text="Designed by Vestmark IT"
                               Foreground="#6b7280" Margin="0,4,0,0"/>
                </StackPanel>
                <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock Name="LblVersion" Text="v1.0.0"
                               FontSize="11" Foreground="#9ca3af" HorizontalAlignment="Right"/>
                    <Button Name="BtnCheckUpdate" Content="Check for Updates"
                            Style="{StaticResource SecondaryBtn}"
                            Padding="12,6" FontSize="11" Margin="0,4,0,0"/>
                </StackPanel>
            </Grid>
        </StackPanel>

        <!-- Persistent Action Buttons (visible on all tabs) -->
        <WrapPanel DockPanel.Dock="Bottom" HorizontalAlignment="Right" Margin="0,8,0,0">
            <Button Name="BtnStartClaude" Content="Start Claude"
                    Style="{StaticResource PrimaryBtn}" Margin="0,0,8,0"/>
            <Button Name="BtnSsoLogin" Content="SSO Login (Refresh Token)"
                    Style="{StaticResource SecondaryBtn}" Margin="0,0,0,0"/>
        </WrapPanel>

        <!-- Status Bar -->
        <Border DockPanel.Dock="Bottom" Background="#e5e7eb" CornerRadius="4"
                Padding="12,8" Margin="0,12,0,0">
            <TextBlock Name="LblStatusBar" Text="Ready" Foreground="#4b5563"/>
        </Border>

        <!-- Tab Control -->
        <TabControl Name="MainTabs" Background="Transparent" BorderThickness="0"
                    Padding="0,8,0,0">

            <!-- ==================== INSTALL TAB ==================== -->
            <TabItem Header="   Install   " FontSize="14" FontWeight="SemiBold">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Margin="0,12,0,0">
                    <StackPanel>

                        <!-- Prerequisites Card -->
                        <Border Style="{StaticResource CardBorder}">
                            <StackPanel>
                                <TextBlock Text="Prerequisite Status" Style="{StaticResource SectionTitle}"/>
                                <TextBlock Text="Tools required by Claude Code. Click Refresh to re-check."
                                           Foreground="#6b7280" Margin="0,0,0,14"/>

                                <!-- Git -->
                                <Grid Margin="0,0,0,8">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="22"/>
                                        <ColumnDefinition Width="110"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Name="DotGit" Text="&#x25CF;" FontSize="14"
                                               Foreground="#9ca3af" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                                    <TextBlock Text="Git" Grid.Column="1" FontWeight="Medium"
                                               Foreground="#374151" VerticalAlignment="Center"/>
                                    <TextBlock Name="StatusGit" Text="Checking..." Grid.Column="2"
                                               Foreground="#6b7280" VerticalAlignment="Center"/>
                                </Grid>

                                <!-- AWS CLI -->
                                <Grid Margin="0,0,0,8">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="22"/>
                                        <ColumnDefinition Width="110"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Name="DotAws" Text="&#x25CF;" FontSize="14"
                                               Foreground="#9ca3af" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                                    <TextBlock Text="AWS CLI" Grid.Column="1" FontWeight="Medium"
                                               Foreground="#374151" VerticalAlignment="Center"/>
                                    <TextBlock Name="StatusAws" Text="Checking..." Grid.Column="2"
                                               Foreground="#6b7280" VerticalAlignment="Center"/>
                                </Grid>

                                <!-- Claude Code -->
                                <Grid Margin="0,0,0,0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="22"/>
                                        <ColumnDefinition Width="110"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Name="DotClaude" Text="&#x25CF;" FontSize="14"
                                               Foreground="#9ca3af" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                                    <TextBlock Text="Claude Code" Grid.Column="1" FontWeight="Medium"
                                               Foreground="#374151" VerticalAlignment="Center"/>
                                    <TextBlock Name="StatusClaude" Text="Checking..." Grid.Column="2"
                                               Foreground="#6b7280" VerticalAlignment="Center"/>
                                </Grid>
                            </StackPanel>
                        </Border>

                        <!-- Action Buttons -->
                        <WrapPanel Margin="0,0,0,8">
                            <Button Name="BtnCheckPrereqs" Content="Refresh Status"
                                    Style="{StaticResource SecondaryBtn}" Margin="0,0,8,4"/>
                            <Button Name="BtnInstallClaude" Content="Install Claude Code"
                                    Style="{StaticResource PrimaryBtn}" Margin="0,0,8,4"/>
                            <Button Name="BtnUninstallClaude" Content="Uninstall Claude Code"
                                    Style="{StaticResource DangerBtn}" Margin="0,0,0,4"/>
                        </WrapPanel>

                        <TextBlock TextWrapping="Wrap" Foreground="#9ca3af" FontSize="11.5" Margin="0,0,0,12"
                                   Text="Git and AWS CLI require an administrator to install system-wide. Claude Code is installed at the user level via the official installer and does not require elevation."/>

                        <!-- Log Card -->
                        <Border Style="{StaticResource CardBorder}">
                            <StackPanel>
                                <TextBlock Text="Output Log" FontSize="14" FontWeight="SemiBold"
                                           Foreground="#1e293b" Margin="0,0,0,8"/>
                                <TextBox Name="TxtLog" IsReadOnly="True" TextWrapping="Wrap"
                                         VerticalScrollBarVisibility="Auto" Height="130"
                                         FontFamily="Consolas" FontSize="11"
                                         Background="#f8fafc" Foreground="#334155"
                                         BorderBrush="#e5e7eb" Padding="8"/>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <!-- ==================== CONFIGURE CLAUDE TAB ==================== -->
            <TabItem Header="   Configure Claude   " FontSize="14" FontWeight="SemiBold">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Margin="0,12,0,0">
                    <StackPanel>

                        <!-- Settings Card -->
                        <Border Style="{StaticResource CardBorder}">
                            <StackPanel>
                                <TextBlock Text="Environment Configuration" Style="{StaticResource SectionTitle}"/>
                                <TextBlock Text="All variables are persisted at User scope - no administrator required."
                                           Foreground="#6b7280" Margin="0,0,0,16"/>

                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="230"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="12"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="12"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="12"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="12"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="16"/>
                                        <RowDefinition Height="Auto"/>
                                    </Grid.RowDefinitions>

                                    <!-- Row 0: AWS Region -->
                                    <TextBlock Text="AWS Region (AWS_REGION):" Grid.Row="0" Grid.Column="0"
                                               Style="{StaticResource FormLabel}"/>
                                    <ComboBox Name="CmbRegion" Grid.Row="0" Grid.Column="1"
                                              Padding="8,6" FontSize="13">
                                        <ComboBoxItem Content="us-east-1" IsSelected="True"/>
                                        <ComboBoxItem Content="us-east-2"/>
                                        <ComboBoxItem Content="us-west-2"/>
                                        <ComboBoxItem Content="eu-west-1"/>
                                        <ComboBoxItem Content="eu-west-2"/>
                                        <ComboBoxItem Content="eu-central-1"/>
                                        <ComboBoxItem Content="ap-northeast-1"/>
                                        <ComboBoxItem Content="ap-southeast-1"/>
                                        <ComboBoxItem Content="ap-southeast-2"/>
                                    </ComboBox>

                                    <!-- Row 2: AWS Profile -->
                                    <TextBlock Text="AWS Profile (AWS_PROFILE):" Grid.Row="2" Grid.Column="0"
                                               Style="{StaticResource FormLabel}"/>
                                    <TextBox Name="TxtProfile" Grid.Row="2" Grid.Column="1"
                                             Text="claude-code" Padding="8,6" FontSize="13"
                                             BorderBrush="#d1d5db"/>

                                    <!-- Row 4: Primary Model -->
                                    <TextBlock Text="Primary Model (ANTHROPIC_MODEL):" Grid.Row="4" Grid.Column="0"
                                               Style="{StaticResource FormLabel}"/>
                                    <ComboBox Name="CmbPrimaryModel" Grid.Row="4" Grid.Column="1"
                                              Padding="8,6" FontSize="13">
                                        <ComboBoxItem Content="Claude Sonnet 4.6"
                                                      Tag="us.anthropic.claude-sonnet-4-6"
                                                      ToolTip="us.anthropic.claude-sonnet-4-6"/>
                                        <ComboBoxItem Content="Claude Sonnet 4.5" IsSelected="True"
                                                      Tag="us.anthropic.claude-sonnet-4-5-20250929-v1:0"
                                                      ToolTip="us.anthropic.claude-sonnet-4-5-20250929-v1:0"/>
                                        <ComboBoxItem Content="Claude Sonnet 4"
                                                      Tag="us.anthropic.claude-sonnet-4-20250514-v1:0"
                                                      ToolTip="us.anthropic.claude-sonnet-4-20250514-v1:0"/>
                                        <ComboBoxItem Content="Claude Haiku 4.5"
                                                      Tag="us.anthropic.claude-haiku-4-5-20251001-v1:0"
                                                      ToolTip="us.anthropic.claude-haiku-4-5-20251001-v1:0"/>
                                    </ComboBox>

                                    <!-- Row 6: Small / Fast Model -->
                                    <TextBlock Text="Small/Fast Model:" Grid.Row="6" Grid.Column="0"
                                               Style="{StaticResource FormLabel}"/>
                                    <ComboBox Name="CmbSmallModel" Grid.Row="6" Grid.Column="1"
                                              Padding="8,6" FontSize="13">
                                        <ComboBoxItem Content="Claude Haiku 3.5"
                                                      Tag="us.anthropic.claude-3-5-haiku-20241022-v1:0"
                                                      ToolTip="us.anthropic.claude-3-5-haiku-20241022-v1:0"/>
                                        <ComboBoxItem Content="Claude Haiku 3" IsSelected="True"
                                                      Tag="us.anthropic.claude-3-haiku-20240307-v1:0"
                                                      ToolTip="us.anthropic.claude-3-haiku-20240307-v1:0"/>
                                        <ComboBoxItem Content="Claude Sonnet 4"
                                                      Tag="us.anthropic.claude-sonnet-4-20250514-v1:0"
                                                      ToolTip="us.anthropic.claude-sonnet-4-20250514-v1:0"/>
                                    </ComboBox>

                                    <!-- Row 8: Default Project Location -->
                                    <TextBlock Text="Default Project Location (optional):" Grid.Row="8" Grid.Column="0"
                                               Style="{StaticResource FormLabel}"/>
                                    <TextBox Name="TxtProjectPath" Grid.Row="8" Grid.Column="1"
                                             Text="" Padding="8,6" FontSize="13"
                                             BorderBrush="#d1d5db" Margin="0,0,8,0"/>
                                    <Button Name="BtnBrowseProject" Grid.Row="8" Grid.Column="2"
                                            Content="Browse..." Style="{StaticResource SecondaryBtn}"
                                            Padding="12,6"/>

                                    <!-- Row 10: Bedrock checkbox -->
                                    <CheckBox Name="ChkBedrock" Grid.Row="10" Grid.Column="0" Grid.ColumnSpan="3"
                                              IsChecked="True" FontSize="13" Foreground="#374151"
                                              Content="  Use AWS Bedrock  (CLAUDE_CODE_USE_BEDROCK = 1)"
                                              FontWeight="Medium"/>
                                </Grid>
                            </StackPanel>
                        </Border>

                        <!-- Action Buttons -->
                        <WrapPanel Margin="0,0,0,12">
                            <Button Name="BtnApplyConfig" Content="Apply Configuration"
                                    Style="{StaticResource PrimaryBtn}" Margin="0,0,8,4"/>
                            <Button Name="BtnLoadConfig" Content="Load Current Values"
                                    Style="{StaticResource SecondaryBtn}" Margin="0,0,0,4"/>
                        </WrapPanel>

                        <!-- Current Config Card -->
                        <Border Style="{StaticResource CardBorder}">
                            <StackPanel>
                                <TextBlock Text="Current Environment Variables" FontSize="14" FontWeight="SemiBold"
                                           Foreground="#1e293b" Margin="0,0,0,8"/>
                                <TextBox Name="TxtConfigOutput" IsReadOnly="True" TextWrapping="Wrap"
                                         VerticalScrollBarVisibility="Auto" Height="130"
                                         FontFamily="Consolas" FontSize="11"
                                         Background="#f8fafc" Foreground="#334155"
                                         BorderBrush="#e5e7eb" Padding="8"/>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <!-- ==================== CONFIGURE AWS SSO TAB ==================== -->
            <TabItem Header="   Configure AWS SSO   " FontSize="14" FontWeight="SemiBold">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Margin="0,12,0,0">
                    <StackPanel>

                        <!-- SSO Settings Card -->
                        <Border Style="{StaticResource CardBorder}">
                            <StackPanel>
                                <TextBlock Text="AWS SSO Configuration" Style="{StaticResource SectionTitle}"/>
                                <TextBlock Text="Configure AWS IAM Identity Center (SSO) for Claude Code. This will open your browser for authentication and then let you select an account and role."
                                           Foreground="#6b7280" TextWrapping="Wrap" Margin="0,0,0,16"/>

                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="200"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="12"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="12"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="12"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="12"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="12"/>
                                        <RowDefinition Height="Auto"/>
                                    </Grid.RowDefinitions>

                                    <!-- Row 0: Session Name -->
                                    <TextBlock Text="Session Name:" Grid.Row="0" Grid.Column="0"
                                               Style="{StaticResource FormLabel}"/>
                                    <TextBox Name="TxtSsoSessionName" Grid.Row="0" Grid.Column="1"
                                             Text="claude-code" Padding="8,6" FontSize="13"
                                             BorderBrush="#d1d5db"/>

                                    <!-- Row 2: SSO Start URL -->
                                    <TextBlock Text="SSO Start URL:" Grid.Row="2" Grid.Column="0"
                                               Style="{StaticResource FormLabel}"/>
                                    <TextBox Name="TxtSsoStartUrl" Grid.Row="2" Grid.Column="1"
                                             Text="https://vestmark-hq.awsapps.com/start#/"
                                             Padding="8,6" FontSize="13" BorderBrush="#d1d5db"/>

                                    <!-- Row 4: SSO Region -->
                                    <TextBlock Text="SSO Region:" Grid.Row="4" Grid.Column="0"
                                               Style="{StaticResource FormLabel}"/>
                                    <ComboBox Name="CmbSsoRegion" Grid.Row="4" Grid.Column="1"
                                              Padding="8,6" FontSize="13">
                                        <ComboBoxItem Content="us-east-1" IsSelected="True"/>
                                        <ComboBoxItem Content="us-east-2"/>
                                        <ComboBoxItem Content="us-west-2"/>
                                        <ComboBoxItem Content="eu-west-1"/>
                                        <ComboBoxItem Content="eu-west-2"/>
                                        <ComboBoxItem Content="eu-central-1"/>
                                    </ComboBox>

                                    <!-- Row 6: Registration Scopes -->
                                    <TextBlock Text="Registration Scopes:" Grid.Row="6" Grid.Column="0"
                                               Style="{StaticResource FormLabel}"/>
                                    <TextBox Name="TxtSsoScopes" Grid.Row="6" Grid.Column="1"
                                             Text="sso:account:access" Padding="8,6" FontSize="13"
                                             BorderBrush="#d1d5db"/>

                                    <!-- Row 8: CLI Default Region -->
                                    <TextBlock Text="CLI Default Region:" Grid.Row="8" Grid.Column="0"
                                               Style="{StaticResource FormLabel}"/>
                                    <ComboBox Name="CmbSsoCliRegion" Grid.Row="8" Grid.Column="1"
                                              Padding="8,6" FontSize="13">
                                        <ComboBoxItem Content="us-east-1" IsSelected="True"/>
                                        <ComboBoxItem Content="us-east-2"/>
                                        <ComboBoxItem Content="us-west-2"/>
                                        <ComboBoxItem Content="eu-west-1"/>
                                        <ComboBoxItem Content="eu-west-2"/>
                                        <ComboBoxItem Content="eu-central-1"/>
                                    </ComboBox>

                                    <!-- Row 10: CLI Output Format -->
                                    <TextBlock Text="CLI Output Format:" Grid.Row="10" Grid.Column="0"
                                               Style="{StaticResource FormLabel}"/>
                                    <ComboBox Name="CmbSsoOutput" Grid.Row="10" Grid.Column="1"
                                              Padding="8,6" FontSize="13">
                                        <ComboBoxItem Content="json" IsSelected="True"/>
                                        <ComboBoxItem Content="yaml"/>
                                        <ComboBoxItem Content="text"/>
                                        <ComboBoxItem Content="table"/>
                                    </ComboBox>
                                </Grid>
                            </StackPanel>
                        </Border>

                        <!-- Action Buttons -->
                        <WrapPanel Margin="0,0,0,8">
                            <Button Name="BtnStartSso" Content="Start SSO Configuration"
                                    Style="{StaticResource PrimaryBtn}" Margin="0,0,8,4"/>
                        </WrapPanel>

                        <TextBlock TextWrapping="Wrap" Foreground="#9ca3af" FontSize="11.5" Margin="0,0,0,12"
                                   Text="Start SSO Configuration will open a terminal to run aws configure sso. Your browser will open for authentication. After signing in, you will select your account and role in the terminal. SSO Login refreshes an existing SSO session."/>

                        <!-- SSO Log Card -->
                        <Border Style="{StaticResource CardBorder}">
                            <StackPanel>
                                <TextBlock Text="SSO Log" FontSize="14" FontWeight="SemiBold"
                                           Foreground="#1e293b" Margin="0,0,0,8"/>
                                <TextBox Name="TxtSsoLog" IsReadOnly="True" TextWrapping="Wrap"
                                         VerticalScrollBarVisibility="Auto" Height="130"
                                         FontFamily="Consolas" FontSize="11"
                                         Background="#f8fafc" Foreground="#334155"
                                         BorderBrush="#e5e7eb" Padding="8"/>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

        </TabControl>
    </DockPanel>
</Window>
'@

# ============================================================
# Create Window & Resolve Named Controls
# ============================================================
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$window.MaxHeight = [System.Windows.SystemParameters]::WorkArea.Height

$LblVersion      = $window.FindName("LblVersion")
$BtnCheckUpdate  = $window.FindName("BtnCheckUpdate")
$LblStatusBar    = $window.FindName("LblStatusBar")
$DotGit          = $window.FindName("DotGit")
$DotAws          = $window.FindName("DotAws")
$DotClaude       = $window.FindName("DotClaude")
$StatusGit       = $window.FindName("StatusGit")
$StatusAws       = $window.FindName("StatusAws")
$StatusClaude    = $window.FindName("StatusClaude")
$BtnCheckPrereqs = $window.FindName("BtnCheckPrereqs")
$BtnInstallClaude= $window.FindName("BtnInstallClaude")
$BtnUninstallClaude = $window.FindName("BtnUninstallClaude")
$TxtLog          = $window.FindName("TxtLog")
$CmbRegion       = $window.FindName("CmbRegion")
$TxtProfile      = $window.FindName("TxtProfile")
$CmbPrimaryModel = $window.FindName("CmbPrimaryModel")
$CmbSmallModel   = $window.FindName("CmbSmallModel")
$TxtProjectPath  = $window.FindName("TxtProjectPath")
$BtnBrowseProject= $window.FindName("BtnBrowseProject")
$ChkBedrock      = $window.FindName("ChkBedrock")
$BtnApplyConfig  = $window.FindName("BtnApplyConfig")
$BtnLoadConfig   = $window.FindName("BtnLoadConfig")
$TxtConfigOutput = $window.FindName("TxtConfigOutput")
$TxtSsoSessionName = $window.FindName("TxtSsoSessionName")
$TxtSsoStartUrl    = $window.FindName("TxtSsoStartUrl")
$CmbSsoRegion      = $window.FindName("CmbSsoRegion")
$TxtSsoScopes      = $window.FindName("TxtSsoScopes")
$CmbSsoCliRegion   = $window.FindName("CmbSsoCliRegion")
$CmbSsoOutput      = $window.FindName("CmbSsoOutput")
$BtnStartSso       = $window.FindName("BtnStartSso")
$BtnSsoLogin       = $window.FindName("BtnSsoLogin")
$BtnStartClaude    = $window.FindName("BtnStartClaude")
$TxtSsoLog         = $window.FindName("TxtSsoLog")

# ============================================================
# Helper Functions
# ============================================================
function Write-AppLog {
    param([string]$Message, [string]$Level = "INFO")
    $stamp = Get-Date -Format "HH:mm:ss"
    $TxtLog.AppendText("[$stamp] [$Level] $Message`r`n")
    $TxtLog.ScrollToEnd()
}

function Get-ToolInfo {
    param([string]$Command, [string[]]$VersionArgs = @("--version"), [string[]]$FallbackPaths = @())

    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $cmd) {
        foreach ($p in $FallbackPaths) {
            if (Test-Path $p) {
                $cmd = Get-Command $p -ErrorAction SilentlyContinue
                break
            }
        }
    }
    if (-not $cmd) { return $null }
    try {
        $ver = & $cmd.Source @VersionArgs 2>&1 | Select-Object -First 1
        return $ver.ToString().Trim()
    } catch {
        return "(found but version unknown)"
    }
}

$script:BrushGreenDot  = [Windows.Media.Brushes]::ForestGreen
$script:BrushRedDot    = [Windows.Media.Brushes]::Crimson
$script:BrushGreenText = [Windows.Media.BrushConverter]::new().ConvertFromString("#059669")
$script:BrushRedText   = [Windows.Media.BrushConverter]::new().ConvertFromString("#dc2626")

function Set-StatusRow {
    param($Dot, $Label, [bool]$Installed, [string]$Detail)
    if ($Installed) {
        $Dot.Foreground  = $script:BrushGreenDot
        $Label.Text      = "Installed - $Detail"
        $Label.Foreground = $script:BrushGreenText
    } else {
        $Dot.Foreground  = $script:BrushRedDot
        $Label.Text      = "Not found"
        $Label.Foreground = $script:BrushRedText
    }
}

function Update-Prerequisites {
    $LblStatusBar.Text = "Checking prerequisites..."
    $window.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Background)

    $env:Path = @(
        [Environment]::GetEnvironmentVariable("Path","Machine"),
        [Environment]::GetEnvironmentVariable("Path","User")
    ) -join ";"

    $gitVer = Get-ToolInfo "git" @("--version") @(
        "$env:ProgramFiles\Git\bin\git.exe",
        "${env:ProgramFiles(x86)}\Git\bin\git.exe")
    Set-StatusRow $DotGit $StatusGit ($null -ne $gitVer) $gitVer

    $awsVer = Get-ToolInfo "aws" @("--version") @(
        "$env:ProgramFiles\Amazon\AWSCLIV2\aws.exe")
    Set-StatusRow $DotAws $StatusAws ($null -ne $awsVer) $awsVer

    $claudeVer = Get-ToolInfo "claude" @("--version") @(
        (Join-Path $env:USERPROFILE ".local\bin\claude.exe"),
        "$env:ProgramFiles\Claude\bin\claude.exe",
        "${env:ProgramFiles(x86)}\Claude\bin\claude.exe",
        (Join-Path $env:LOCALAPPDATA "Claude\bin\claude.exe"),
        (Join-Path $env:APPDATA "npm\claude.cmd"))
    Set-StatusRow $DotClaude $StatusClaude ($null -ne $claudeVer) $claudeVer

    $script:ClaudeInstalled = ($null -ne $claudeVer)
    $script:GitInstalled    = ($null -ne $gitVer)
    $script:AwsInstalled    = ($null -ne $awsVer)

    $prereqsMet = $script:GitInstalled -and $script:AwsInstalled
    $BtnInstallClaude.IsEnabled = $prereqsMet
    if (-not $prereqsMet) {
        $missing = @()
        if (-not $script:GitInstalled) { $missing += "Git" }
        if (-not $script:AwsInstalled) { $missing += "AWS CLI" }
        $BtnInstallClaude.ToolTip = "Requires: $($missing -join ', ')"
    } else {
        $BtnInstallClaude.ToolTip = $null
    }

    # Enable/disable Start Claude button based on Claude Code installation
    $BtnStartClaude.IsEnabled = $script:ClaudeInstalled
    if (-not $script:ClaudeInstalled) {
        $BtnStartClaude.ToolTip = "Requires Claude Code to be installed"
    } else {
        $BtnStartClaude.ToolTip = $null
    }

    # Enable/disable SSO buttons based on AWS CLI installation
    $BtnStartSso.IsEnabled = $script:AwsInstalled
    $BtnSsoLogin.IsEnabled = $script:AwsInstalled
    if (-not $script:AwsInstalled) {
        $BtnStartSso.ToolTip = "Requires AWS CLI to be installed"
        $BtnSsoLogin.ToolTip = "Requires AWS CLI to be installed"
    } else {
        $BtnStartSso.ToolTip = $null
        $BtnSsoLogin.ToolTip = $null
    }

    $LblStatusBar.Text = "Ready"
}

function Add-ClaudeToUserPath {
    $claudeBin = Join-Path $env:USERPROFILE ".local\bin"
    if (-not (Test-Path (Join-Path $claudeBin "claude.exe"))) { return $false }
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $entries = $userPath -split ';' | Where-Object { $_ }
    if ($entries -contains $claudeBin) { return $false }
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$claudeBin", "User")
    $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [Environment]::GetEnvironmentVariable("Path","User")
    Send-EnvironmentBroadcast
    return $true
}

function Select-ComboBoxByTag {
    param($ComboBox, [string]$TagValue)
    for ($i = 0; $i -lt $ComboBox.Items.Count; $i++) {
        if ($ComboBox.Items[$i].Tag -eq $TagValue) {
            $ComboBox.SelectedIndex = $i
            return
        }
    }
}

function Select-ComboBoxByContent {
    param($ComboBox, [string]$ContentValue)
    for ($i = 0; $i -lt $ComboBox.Items.Count; $i++) {
        if ($ComboBox.Items[$i].Content -eq $ContentValue) {
            $ComboBox.SelectedIndex = $i
            return
        }
    }
}

function Send-EnvironmentBroadcast {
    try {
        [UIntPtr]$result = [UIntPtr]::Zero
        [void][NativeHelper]::SendMessageTimeout(
            [IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, "Environment", 0x0002, 5000, [ref]$result)
    } catch {}
}

function Get-LatestScriptVersion {
    try {
        $latestContent = Invoke-WebRequest -Uri $script:GitHubRawUrl -UseBasicParsing -TimeoutSec 10
        if ($latestContent.Content -match '\$script:ScriptVersion\s*=\s*"([^"]+)"') {
            return $matches[1]
        }
    } catch {
        return $null
    }
    return $null
}

function Compare-Version {
    param([string]$Version1, [string]$Version2)
    $v1Parts = $Version1.Split('.')
    $v2Parts = $Version2.Split('.')
    $maxLength = [Math]::Max($v1Parts.Length, $v2Parts.Length)

    for ($i = 0; $i -lt $maxLength; $i++) {
        $v1Part = if ($i -lt $v1Parts.Length) { [int]$v1Parts[$i] } else { 0 }
        $v2Part = if ($i -lt $v2Parts.Length) { [int]$v2Parts[$i] } else { 0 }

        if ($v1Part -lt $v2Part) { return -1 }
        if ($v1Part -gt $v2Part) { return 1 }
    }
    return 0
}

function Update-Script {
    param([string]$NewVersion)

    try {
        Write-AppLog "Downloading version $NewVersion from GitHub..."
        $latestContent = Invoke-WebRequest -Uri $script:GitHubRawUrl -UseBasicParsing -TimeoutSec 30

        $backupPath = $script:ScriptPath + ".backup"
        Write-AppLog "Creating backup at: $backupPath"
        Copy-Item -Path $script:ScriptPath -Destination $backupPath -Force

        Write-AppLog "Installing new version..."
        [System.IO.File]::WriteAllText($script:ScriptPath, $latestContent.Content, [System.Text.Encoding]::UTF8)

        Write-AppLog "Update complete! Restart the application to use version $NewVersion." "OK"
        $LblStatusBar.Text = "Update complete - restart required"

        $result = [System.Windows.MessageBox]::Show(
            "Script updated successfully to version $NewVersion.`n`nRestart the application now?",
            "Update Complete",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Information)

        if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
            Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($script:ScriptPath)`"")
            $window.Close()
        }

        return $true
    } catch {
        Write-AppLog "Update failed: $($_.Exception.Message)" "ERROR"
        $LblStatusBar.Text = "Update failed"
        [System.Windows.MessageBox]::Show(
            "Failed to update script:`n$($_.Exception.Message)`n`nBackup preserved at: $backupPath",
            "Update Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error)
        return $false
    }
}

function Check-ScriptUpdate {
    param([bool]$Silent = $false)

    $LblStatusBar.Text = "Checking for updates..."
    Write-AppLog "Checking for updates... (Current: v$($script:ScriptVersion))"

    $latestVersion = Get-LatestScriptVersion

    if ($null -eq $latestVersion) {
        Write-AppLog "Unable to check for updates. Check your internet connection." "WARN"
        $LblStatusBar.Text = "Update check failed"
        if (-not $Silent) {
            [System.Windows.MessageBox]::Show(
                "Unable to check for updates. Please verify your internet connection.",
                "Update Check Failed",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning)
        }
        return
    }

    Write-AppLog "Latest version on GitHub: v$latestVersion"
    $comparison = Compare-Version $script:ScriptVersion $latestVersion

    if ($comparison -lt 0) {
        Write-AppLog "Update available: v$latestVersion" "OK"
        $LblStatusBar.Text = "Update available: v$latestVersion"

        $result = [System.Windows.MessageBox]::Show(
            "A new version is available!`n`nCurrent version: $($script:ScriptVersion)`nLatest version: $latestVersion`n`nWould you like to update now?",
            "Update Available",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Information)

        if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
            Update-Script -NewVersion $latestVersion
        }
    } elseif ($comparison -eq 0) {
        Write-AppLog "You are running the latest version." "OK"
        $LblStatusBar.Text = "Up to date (v$($script:ScriptVersion))"
        if (-not $Silent) {
            [System.Windows.MessageBox]::Show(
                "You are running the latest version ($($script:ScriptVersion)).",
                "Up to Date",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information)
        }
    } else {
        Write-AppLog "Your version is newer than GitHub (dev version?)." "INFO"
        $LblStatusBar.Text = "Development version detected"
        if (-not $Silent) {
            [System.Windows.MessageBox]::Show(
                "Your version ($($script:ScriptVersion)) is newer than the latest on GitHub ($latestVersion).`n`nYou may be running a development version.",
                "Newer Version Detected",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information)
        }
    }
}

function Show-CurrentConfig {
    $vars = @(
        "CLAUDE_CODE_USE_BEDROCK",
        "AWS_REGION",
        "AWS_PROFILE",
        "ANTHROPIC_MODEL",
        "ANTHROPIC_SMALL_FAST_MODEL",
        "CLAUDE_CODE_DEFAULT_PROJECT",
        "CLAUDE_CODE_GIT_BASH_PATH"
    )
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("--- User Scope ---")
    foreach ($v in $vars) {
        $val = [Environment]::GetEnvironmentVariable($v, "User")
        if ($null -eq $val) { $val = "(not set)" }
        [void]$sb.AppendLine("${v} = $val")
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("--- Machine Scope (read-only) ---")
    foreach ($v in $vars) {
        $val = [Environment]::GetEnvironmentVariable($v, "Machine")
        if ($null -eq $val) { $val = "(not set)" }
        [void]$sb.AppendLine("${v} = $val")
    }
    $TxtConfigOutput.Text = $sb.ToString()
}

function Import-ConfigIntoForm {
    $envNames = @("AWS_REGION","AWS_PROFILE","ANTHROPIC_MODEL","ANTHROPIC_SMALL_FAST_MODEL","CLAUDE_CODE_USE_BEDROCK","CLAUDE_CODE_DEFAULT_PROJECT")
    $values = @{}
    foreach ($n in $envNames) {
        $val = [Environment]::GetEnvironmentVariable($n, "User")
        if ([string]::IsNullOrEmpty($val)) {
            $val = [Environment]::GetEnvironmentVariable($n, "Machine")
        }
        $values[$n] = $val
    }

    if ($values["AWS_REGION"])  { Select-ComboBoxByContent $CmbRegion $values["AWS_REGION"] }
    if ($values["AWS_PROFILE"]) { $TxtProfile.Text = $values["AWS_PROFILE"] }
    if ($values["ANTHROPIC_MODEL"]) { Select-ComboBoxByTag $CmbPrimaryModel $values["ANTHROPIC_MODEL"] }
    if ($values["ANTHROPIC_SMALL_FAST_MODEL"]) { Select-ComboBoxByTag $CmbSmallModel $values["ANTHROPIC_SMALL_FAST_MODEL"] }
    if ($values["CLAUDE_CODE_DEFAULT_PROJECT"]) { $TxtProjectPath.Text = $values["CLAUDE_CODE_DEFAULT_PROJECT"] }
    if ($values["CLAUDE_CODE_USE_BEDROCK"]) {
        $ChkBedrock.IsChecked = ($values["CLAUDE_CODE_USE_BEDROCK"] -eq "1")
    }

    Show-CurrentConfig
    $LblStatusBar.Text = "Loaded current environment values"
}

# ============================================================
# Event Handlers
# ============================================================

# --- Refresh Status ---
$BtnCheckPrereqs.Add_Click({
    Write-AppLog "Refreshing prerequisite status..."
    Update-Prerequisites
    Write-AppLog "Prerequisite check complete." "OK"
})

# --- Install Claude Code ---
$script:installProc = $null

$script:onInstallTick = {
    try {
        $p = $script:installProc
        if ($null -eq $p) { return }
        $exited = $p.HasExited
    } catch {
        $exited = $true
    }
    if ($exited) {
        $script:installTimer.Stop()
        $script:installProc = $null
        Write-AppLog "Installer window closed."

        $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                    [Environment]::GetEnvironmentVariable("Path","User")

        if (Add-ClaudeToUserPath) {
            Write-AppLog "Added $($env:USERPROFILE)\.local\bin to User PATH." "OK"
        }

        Send-EnvironmentBroadcast
        Update-Prerequisites

        if ($script:ClaudeInstalled) {
            Write-AppLog "Claude Code installed successfully!" "OK"
            $LblStatusBar.Text = "Claude Code installed."
        } else {
            Write-AppLog "Claude Code not detected. The installer may have been cancelled." "WARN"
            $LblStatusBar.Text = "Installation not confirmed - click Refresh Status to re-check."
        }

        $prereqsMet = $script:GitInstalled -and $script:AwsInstalled
        $BtnInstallClaude.IsEnabled   = $prereqsMet
        $BtnCheckPrereqs.IsEnabled    = $true
        $BtnUninstallClaude.IsEnabled = $true
    }
}

$BtnInstallClaude.Add_Click({
    $BtnInstallClaude.IsEnabled   = $false
    $BtnCheckPrereqs.IsEnabled    = $false
    $BtnUninstallClaude.IsEnabled = $false
    $LblStatusBar.Text = "Installer window opened - complete the install there, then return here."
    Write-AppLog "Launching official Claude Code installer in a new terminal..."

    $installCmd = "Write-Host 'Claude Code Installer' -ForegroundColor Cyan; Write-Host '=====================' -ForegroundColor Cyan; Write-Host ''; irm https://claude.ai/install.ps1 | iex; Write-Host ''; Write-Host 'Installation complete. You may close this window.' -ForegroundColor Green; pause"

    $script:installProc = Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $installCmd) -PassThru

    $script:installTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:installTimer.Interval = [TimeSpan]::FromSeconds(2)
    $script:installTimer.Add_Tick($script:onInstallTick)
    $script:installTimer.Start()
})

# --- Uninstall Claude Code ---
$script:onUninstallTick = {
    try {
        $j = $script:uninstallJob
        if ($null -eq $j) { return }
        $done = ($j.State -eq 'Completed' -or $j.State -eq 'Failed')
    } catch {
        $done = $true
    }
    if ($done) {
        $script:uninstallTimer.Stop()
        $output = Receive-Job -Job $j -ErrorAction SilentlyContinue
        Remove-Job -Job $j -Force -ErrorAction SilentlyContinue
        $script:uninstallJob = $null
        if ($output) { foreach ($line in $output) { Write-AppLog $line.ToString() } }
        Update-Prerequisites
        Write-AppLog "Claude Code uninstalled." "OK"
        $LblStatusBar.Text = "Claude Code uninstalled."
        $prereqsMet = $script:GitInstalled -and $script:AwsInstalled
        $BtnInstallClaude.IsEnabled   = $prereqsMet
        $BtnCheckPrereqs.IsEnabled    = $true
        $BtnUninstallClaude.IsEnabled = $true
    }
}

$BtnUninstallClaude.Add_Click({
    $result = [System.Windows.MessageBox]::Show(
        "Are you sure you want to uninstall Claude Code?",
        "Confirm Uninstall",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question)

    if ($result -ne [System.Windows.MessageBoxResult]::Yes) { return }

    $BtnInstallClaude.IsEnabled   = $false
    $BtnCheckPrereqs.IsEnabled    = $false
    $BtnUninstallClaude.IsEnabled = $false
    $LblStatusBar.Text = "Uninstalling Claude Code..."
    Write-AppLog "Uninstalling Claude Code..."

    $script:uninstallJob = Start-Job -ScriptBlock {
        $ErrorActionPreference = 'Continue'
        $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                    [Environment]::GetEnvironmentVariable("Path","User")
        $pathsToRemove = @(
            (Join-Path $env:USERPROFILE ".claude"),
            (Join-Path $env:USERPROFILE ".local\bin\claude.exe")
        )
        foreach ($p in $pathsToRemove) {
            if (Test-Path $p) {
                Remove-Item -Path $p -Recurse -Force 2>&1
                "Removed $p"
            }
        }
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            npm uninstall -g @anthropic-ai/claude-code 2>&1
        }
    }

    $script:uninstallTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:uninstallTimer.Interval = [TimeSpan]::FromSeconds(2)
    $script:uninstallTimer.Add_Tick($script:onUninstallTick)
    $script:uninstallTimer.Start()
})

# --- Apply Configuration ---
$BtnApplyConfig.Add_Click({
    $BtnApplyConfig.IsEnabled = $false
    $LblStatusBar.Text = "Applying configuration..."

    try {
        $region  = $CmbRegion.SelectedItem.Content
        $awsProfile = $TxtProfile.Text.Trim()
        $primaryModelId = $CmbPrimaryModel.SelectedItem.Tag
        $smallModelId   = $CmbSmallModel.SelectedItem.Tag
        $projectPath    = $TxtProjectPath.Text.Trim()
        $useBedrock     = if ($ChkBedrock.IsChecked) { "1" } else { "0" }

        if ([string]::IsNullOrWhiteSpace($awsProfile)) {
            [System.Windows.MessageBox]::Show("AWS Profile cannot be empty.", "Validation",
                [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
            $BtnApplyConfig.IsEnabled = $true
            return
        }

        $vars = [ordered]@{
            'CLAUDE_CODE_USE_BEDROCK'    = $useBedrock
            'AWS_REGION'                 = $region
            'AWS_PROFILE'                = $awsProfile
            'ANTHROPIC_MODEL'            = $primaryModelId
            'ANTHROPIC_SMALL_FAST_MODEL' = $smallModelId
            'CLAUDE_CODE_DEFAULT_PROJECT'= $projectPath
        }

        foreach ($k in $vars.Keys) {
            [Environment]::SetEnvironmentVariable($k, $vars[$k], 'User')
            Set-Item -Path "Env:$k" -Value $vars[$k]
        }

        $bashPath = @(
            "$env:ProgramFiles\Git\bin\bash.exe",
            "$env:ProgramFiles\Git\usr\bin\bash.exe",
            "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1

        if ($bashPath) {
            [Environment]::SetEnvironmentVariable("CLAUDE_CODE_GIT_BASH_PATH", $bashPath, "User")
            Set-Item -Path "Env:CLAUDE_CODE_GIT_BASH_PATH" -Value $bashPath
        }

        Add-ClaudeToUserPath | Out-Null

        Send-EnvironmentBroadcast
        Show-CurrentConfig

        $LblStatusBar.Text = "Configuration applied successfully."
        [System.Windows.MessageBox]::Show(
            "Environment variables have been set at User scope.`n`nOpen a NEW terminal for the changes to take effect.",
            "Configuration Applied",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information)
    }
    catch {
        $LblStatusBar.Text = "Error applying configuration."
        [System.Windows.MessageBox]::Show(
            "Failed to apply configuration:`n$($_.Exception.Message)",
            "Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error)
    }
    finally {
        $BtnApplyConfig.IsEnabled = $true
    }
})

# --- Load Current Config ---
$BtnLoadConfig.Add_Click({
    Import-ConfigIntoForm
})

# --- Browse Project Folder ---
$BtnBrowseProject.Add_Click({
    Add-Type -AssemblyName System.Windows.Forms
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select your default Claude Code project directory"
    $folderBrowser.ShowNewFolderButton = $true

    # Set initial directory if one is already specified
    $currentPath = $TxtProjectPath.Text.Trim()
    if (-not [string]::IsNullOrWhiteSpace($currentPath) -and (Test-Path $currentPath)) {
        $folderBrowser.SelectedPath = $currentPath
    } else {
        $folderBrowser.SelectedPath = [Environment]::GetFolderPath("MyDocuments")
    }

    $result = $folderBrowser.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $TxtProjectPath.Text = $folderBrowser.SelectedPath
    }
})

# --- SSO Log Helper ---
function Write-SsoLog {
    param([string]$Message, [string]$Level = "INFO")
    $stamp = Get-Date -Format "HH:mm:ss"
    $TxtSsoLog.AppendText("[$stamp] [$Level] $Message`r`n")
    $TxtSsoLog.ScrollToEnd()
}

# --- Start SSO Configuration ---
$script:ssoProc = $null

$script:onSsoTick = {
    try {
        $p = $script:ssoProc
        if ($null -eq $p) { return }
        $exited = $p.HasExited
    } catch {
        $exited = $true
    }
    if ($exited) {
        $script:ssoTimer.Stop()
        $script:ssoProc = $null
        Write-SsoLog "SSO configuration terminal closed."

        $profileName = $TxtSsoSessionName.Text.Trim()
        $awsConfigFile = Join-Path $env:USERPROFILE ".aws\config"
        if ((Test-Path $awsConfigFile) -and (Select-String -Path $awsConfigFile -Pattern "profile $profileName" -Quiet -ErrorAction SilentlyContinue)) {
            Write-SsoLog "AWS profile '$profileName' found in ~/.aws/config." "OK"
            $LblStatusBar.Text = "SSO profile '$profileName' configured successfully."
        } else {
            Write-SsoLog "AWS profile '$profileName' not found. SSO setup may have been cancelled." "WARN"
            $LblStatusBar.Text = "SSO configuration may not have completed."
        }

        $BtnStartSso.IsEnabled = $true
        $BtnSsoLogin.IsEnabled = $true
    }
}

$BtnStartSso.Add_Click({
    $sessionName = $TxtSsoSessionName.Text.Trim()
    $startUrl    = $TxtSsoStartUrl.Text.Trim()
    $ssoRegion   = $CmbSsoRegion.SelectedItem.Content
    $scopes      = $TxtSsoScopes.Text.Trim()
    $cliRegion   = $CmbSsoCliRegion.SelectedItem.Content
    $outFormat   = $CmbSsoOutput.SelectedItem.Content

    if ([string]::IsNullOrWhiteSpace($sessionName) -or [string]::IsNullOrWhiteSpace($startUrl)) {
        [System.Windows.MessageBox]::Show("Session Name and SSO Start URL are required.", "Validation",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $BtnStartSso.IsEnabled = $false
    $BtnSsoLogin.IsEnabled = $false
    $LblStatusBar.Text = "SSO terminal opened - complete the setup there."
    Write-SsoLog "Launching aws configure sso..."
    Write-SsoLog "Session: $sessionName | URL: $startUrl | Region: $ssoRegion"

    # Write only the [sso-session] block so aws configure sso can reference it
    $awsDir = Join-Path $env:USERPROFILE ".aws"
    if (-not (Test-Path $awsDir)) { New-Item -Path $awsDir -ItemType Directory -Force | Out-Null }
    $configFile = Join-Path $awsDir "config"

    $ssoSessionText = "[sso-session $sessionName]`nsso_start_url = $startUrl`nsso_region = $ssoRegion`nsso_registration_scopes = $scopes"

    if (Test-Path $configFile) {
        $content = [System.IO.File]::ReadAllText($configFile)
    } else {
        $content = ""
    }

    $sessionPattern = "(?s)\[sso-session $([regex]::Escape($sessionName))\].*?(?=\r?\n\[|\z)"

    if ($content -match [regex]::Escape("[sso-session $sessionName]")) {
        $content = $content -replace $sessionPattern, "$ssoSessionText`n"
    } else {
        $content = $content.TrimEnd() + "`n`n$ssoSessionText`n"
    }

    # Remove any incomplete profile that is missing sso_account_id
    $profilePattern = "(?s)\[profile $([regex]::Escape($sessionName))\].*?(?=\r?\n\[|\z)"
    $content = $content -replace $profilePattern, ""

    [System.IO.File]::WriteAllText($configFile, $content.Trim() + "`n")
    Write-SsoLog "Wrote SSO session to ~/.aws/config" "OK"

    # Run aws configure sso interactively so the user can select account and role
    $ssoCmd = @(
        "`$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')"
        "Write-Host 'AWS SSO Configuration' -ForegroundColor Cyan"
        "Write-Host '=====================' -ForegroundColor Cyan"
        "Write-Host ''"
        "Write-Host 'When prompted:' -ForegroundColor Yellow"
        "Write-Host '  SSO session name  -> type: $sessionName' -ForegroundColor Yellow"
        "Write-Host '  Select account    -> choose your account (e.g. eng-infrastructure)' -ForegroundColor Yellow"
        "Write-Host '  Select role       -> choose your role' -ForegroundColor Yellow"
        "Write-Host '  Default region    -> $cliRegion' -ForegroundColor Yellow"
        "Write-Host '  Output format     -> $outFormat' -ForegroundColor Yellow"
        "Write-Host '  Profile name      -> $sessionName' -ForegroundColor Yellow"
        "Write-Host ''"
        "aws configure sso"
        "Write-Host ''"
        "Write-Host 'SSO configuration complete. You may close this window.' -ForegroundColor Green"
        "pause"
    ) -join '; '

    $script:ssoProc = Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $ssoCmd) -PassThru

    $script:ssoTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:ssoTimer.Interval = [TimeSpan]::FromSeconds(2)
    $script:ssoTimer.Add_Tick($script:onSsoTick)
    $script:ssoTimer.Start()
})

# --- SSO Login (Refresh Token) ---
$script:ssoLoginProc = $null

$script:onSsoLoginTick = {
    try {
        $p = $script:ssoLoginProc
        if ($null -eq $p) { return }
        $exited = $p.HasExited
    } catch {
        $exited = $true
    }
    if ($exited) {
        $script:ssoLoginTimer.Stop()
        $script:ssoLoginProc = $null
        Write-SsoLog "SSO login terminal closed." "OK"
        $LblStatusBar.Text = "SSO login complete."
        $BtnStartSso.IsEnabled = $true
        $BtnSsoLogin.IsEnabled = $true
    }
}

$BtnSsoLogin.Add_Click({
    $sessionName = $TxtSsoSessionName.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($sessionName)) {
        [System.Windows.MessageBox]::Show("Session Name is required.", "Validation",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $BtnStartSso.IsEnabled = $false
    $BtnSsoLogin.IsEnabled = $false
    $LblStatusBar.Text = "SSO login window opened - authenticate in your browser."
    Write-SsoLog "Launching aws sso login --profile $sessionName..."

    $loginCmd = @(
        "`$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')"
        "Write-Host 'AWS SSO Login' -ForegroundColor Cyan"
        "Write-Host '=============' -ForegroundColor Cyan"
        "Write-Host ''"
        "aws sso login --profile $sessionName"
        "Write-Host ''"
        "Write-Host 'SSO login complete. You may close this window.' -ForegroundColor Green"
        "pause"
    ) -join '; '

    $script:ssoLoginProc = Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $loginCmd) -PassThru

    $script:ssoLoginTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:ssoLoginTimer.Interval = [TimeSpan]::FromSeconds(2)
    $script:ssoLoginTimer.Add_Tick($script:onSsoLoginTick)
    $script:ssoLoginTimer.Start()
})

# --- Start Claude ---
$BtnStartClaude.Add_Click({
    $LblStatusBar.Text = "Launching Claude Code terminal..."

    # Get the default project path from environment variable
    $projectPath = [Environment]::GetEnvironmentVariable("CLAUDE_CODE_DEFAULT_PROJECT", "User")
    if ([string]::IsNullOrWhiteSpace($projectPath)) {
        $projectPath = [Environment]::GetEnvironmentVariable("CLAUDE_CODE_DEFAULT_PROJECT", "Machine")
    }

    $claudeCmd = @(
        "`$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')"
        "Write-Host 'Claude Code' -ForegroundColor Cyan"
        "Write-Host '===========' -ForegroundColor Cyan"
        "Write-Host ''"
    )

    # Add cd command if project path is set and valid
    if (-not [string]::IsNullOrWhiteSpace($projectPath) -and (Test-Path $projectPath)) {
        $claudeCmd += "Write-Host 'Navigating to: $projectPath' -ForegroundColor Yellow"
        $claudeCmd += "cd `"$projectPath`""
        $claudeCmd += "Write-Host ''"
    }

    $claudeCmd += "claude"

    Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', ($claudeCmd -join '; '))
    $LblStatusBar.Text = "Claude Code terminal launched."
})

# --- Check for Updates ---
$BtnCheckUpdate.Add_Click({
    Check-ScriptUpdate -Silent $false
})

# ============================================================
# Initialization - deferred until the window is visible
# ============================================================
$window.Add_ContentRendered({
    $LblVersion.Text = "v$($script:ScriptVersion)"
    Update-Prerequisites
    Import-ConfigIntoForm
    Write-AppLog "Claude Code Assistant v$($script:ScriptVersion) ready."

    # Silent check for updates on startup (non-blocking)
    Start-Job -ScriptBlock {
        param($Version, $Url)
        try {
            $content = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10
            if ($content.Content -match '\$script:ScriptVersion\s*=\s*"([^"]+)"') {
                $latestVersion = $matches[1]
                $v1Parts = $Version.Split('.')
                $v2Parts = $latestVersion.Split('.')
                $maxLength = [Math]::Max($v1Parts.Length, $v2Parts.Length)

                for ($i = 0; $i -lt $maxLength; $i++) {
                    $v1Part = if ($i -lt $v1Parts.Length) { [int]$v1Parts[$i] } else { 0 }
                    $v2Part = if ($i -lt $v2Parts.Length) { [int]$v2Parts[$i] } else { 0 }

                    if ($v1Part -lt $v2Part) {
                        return @{UpdateAvailable=$true; LatestVersion=$latestVersion}
                    }
                    if ($v1Part -gt $v2Part) { break }
                }
            }
        } catch {}
        return @{UpdateAvailable=$false}
    } -ArgumentList $script:ScriptVersion, $script:GitHubRawUrl | Out-Null
})

# ============================================================
# Show Window
# ============================================================
$window.ShowDialog() | Out-Null
