// ************************************************************************
// ***************************** CEF4Delphi *******************************
// ************************************************************************
//
// CEF4Delphi is based on DCEF3 which uses CEF3 to embed a chromium-based
// browser in Delphi applications.
//
// The original license of DCEF3 still applies to CEF4Delphi.
//
// For more information about CEF4Delphi visit :
//         https://www.briskbard.com/index.php?lang=en&pageid=cef
//
//        Copyright � 2017 Salvador D�az Fau. All rights reserved.
//
// ************************************************************************
// ************ vvvv Original license and comments below vvvv *************
// ************************************************************************
(*
 *                       Delphi Chromium Embedded 3
 *
 * Usage allowed under the restrictions of the Lesser GNU General Public License
 * or alternatively the restrictions of the Mozilla Public License 1.1
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
 * the specific language governing rights and limitations under the License.
 *
 * Unit owner : Henri Gourvest <hgourvest@gmail.com>
 * Web site   : http://www.progdigy.com
 * Repository : http://code.google.com/p/delphichromiumembedded/
 * Group      : http://groups.google.com/group/delphichromiumembedded
 *
 * Embarcadero Technologies, Inc is not permitted to use or redistribute
 * this source code without explicit permission.
 *
 *)

program DOMVisitor;

{$I cef.inc}

uses
  {$IFDEF DELPHI16_UP}
  Vcl.Forms,
  WinApi.Windows,
  System.SysUtils,
  {$ELSE}
  Forms,
  Windows,
  SysUtils,
  {$ENDIF }
  uCEFApplication,
  uCEFMiscFunctions,
  uCEFSchemeRegistrar,
  uCEFRenderProcessHandler,
  uCEFv8Handler,
  uCEFInterfaces,
  uCEFDomVisitor,
  uCEFDomNode,
  uCEFConstants,
  uCEFTypes,
  uCEFTask,
  uCEFProcessMessage,
  uDOMVisitor in 'uDOMVisitor.pas' {DOMVisitorFrm};

{$R *.res}

// CEF3 needs to set the LARGEADDRESSAWARE flag which allows 32-bit processes to use up to 3GB of RAM.
{$SetPEFlags IMAGE_FILE_LARGE_ADDRESS_AWARE}

var
  TempProcessHandler : TCefCustomRenderProcessHandler;

procedure SimpleDOMIteration(const aDocument: ICefDomDocument);
var
  TempHead, TempChild : ICefDomNode;
begin
  try
    if (aDocument <> nil) then
      begin
        TempHead := aDocument.Head;

        if (TempHead <> nil) then
          begin
            TempChild := TempHead.FirstChild;

            while (TempChild <> nil) do
              begin
                CefLog('CEF4Delphi', 1, CEF_LOG_SEVERITY_ERROR, 'Head child element : ' + TempChild.Name);
                TempChild := TempChild.NextSibling;
              end;
          end;
      end;
  except
    on e : exception do
      if CustomExceptionHandler('SimpleDOMIteration', e) then raise;
  end;
end;

procedure SimpleNodeSearch(const aDocument: ICefDomDocument);
const
  NODE_ID = 'lst-ib'; // node found in google.com homepage
var
  TempNode : ICefDomNode;
begin
  try
    if (aDocument <> nil) then
      begin
        TempNode := aDocument.GetElementById(NODE_ID);

        if (TempNode <> nil) then
          CefLog('CEF4Delphi', 1, CEF_LOG_SEVERITY_ERROR, NODE_ID + ' element name : ' + TempNode.Name);

        TempNode := aDocument.GetFocusedNode;

        if (TempNode <> nil) then
          CefLog('CEF4Delphi', 1, CEF_LOG_SEVERITY_ERROR, 'Focused element name : ' + TempNode.Name);
      end;
  except
    on e : exception do
      if CustomExceptionHandler('SimpleNodeSearch', e) then raise;
  end;
end;

procedure DOMVisitor_OnDocAvailable(const browser: ICefBrowser; const document: ICefDomDocument);
var
  msg: ICefProcessMessage;
begin
  // This function is called from a different process.
  // document is only valid inside this function.
  // As an example, this function only writes the document title to the 'debug.log' file.
  CefLog('CEF4Delphi', 1, CEF_LOG_SEVERITY_ERROR, 'document.Title : ' + document.Title);

  // Simple DOM iteration example
  SimpleDOMIteration(document);

  // Simple DOM searches
  SimpleNodeSearch(document);

  // Sending back some custom results to the browser process
  // Notice that the DOMVISITOR_MSGNAME message name needs to be recognized in
  // Chromium1ProcessMessageReceived
  msg := TCefProcessMessageRef.New(DOMVISITOR_MSGNAME);
  msg.ArgumentList.SetString(0, 'document.Title : ' + document.Title);
  browser.SendProcessMessage(PID_BROWSER, msg);
end;

procedure ProcessHandler_OnProcessMessageReceivedEvent(const browser       : ICefBrowser;
                                                             sourceProcess : TCefProcessId;
                                                       const message       : ICefProcessMessage);
var
  TempFrame   : ICefFrame;
  TempVisitor : TCefFastDomVisitor2;
begin
  if (browser <> nil) then
    begin
      TempFrame := browser.MainFrame;

      if (TempFrame <> nil) then
        begin
          TempVisitor := TCefFastDomVisitor2.Create(browser, DOMVisitor_OnDocAvailable);
          TempFrame.VisitDom(TempVisitor);
        end;
    end;
end;

begin
  // This ProcessHandler is used for the extension and the DOM visitor demos.
  // It can be removed if you don't want those features.
  TempProcessHandler                               := TCefCustomRenderProcessHandler.Create;
  TempProcessHandler.MessageName                   := RETRIEVEDOM_MSGNAME;   // same message name than TMiniBrowserFrm.VisitDOMMsg
  TempProcessHandler.OnProcessMessageReceivedEvent := ProcessHandler_OnProcessMessageReceivedEvent;

  GlobalCEFApp                      := TCefApplication.Create;
  GlobalCEFApp.RemoteDebuggingPort  := 9000;
  GlobalCEFApp.RenderProcessHandler := TempProcessHandler as ICefRenderProcessHandler;

  // In case you want to use custom directories for the CEF3 binaries, cache, cookies and user data.
{
  GlobalCEFApp.FrameworkDirPath     := 'cef';
  GlobalCEFApp.ResourcesDirPath     := 'cef';
  GlobalCEFApp.LocalesDirPath       := 'cef\locales';
  GlobalCEFApp.cache                := 'cef\cache';
  GlobalCEFApp.cookies              := 'cef\cookies';
  GlobalCEFApp.UserDataPath         := 'cef\User Data';
}

  // Enabling the debug log file for then DOM visitor demo.
  // This adds lots of warnings to the console, specially if you run this inside VirtualBox.
  // Remove it if you don't want to use the DOM visitor
  GlobalCEFApp.LogFile              := 'debug.log';
  GlobalCEFApp.LogSeverity          := LOGSEVERITY_ERROR;


  if GlobalCEFApp.StartMainProcess then
    begin
      Application.Initialize;
      Application.MainFormOnTaskbar := True;
      Application.CreateForm(TDOMVisitorFrm, DOMVisitorFrm);
      Application.Run;
    end;

  GlobalCEFApp.Free;
end.
