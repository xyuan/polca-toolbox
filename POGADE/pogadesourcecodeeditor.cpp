#include "pogadesourcecodeeditor.h"
#include "ui_pogadesourcecodeeditor.h"

#include "pogademainwindow.h"
#include "pogaderevisioncreate.h"
#include "polcapragma.h"
#include "polcascope.h"
#include "scopeneighbourinfo.h"
#include "pogadedefines.h"
#include "toolswait.h"

#include <Qsci/qscilexercpp.h>
#include <QMessageBox>
#include <QDebug>
#include <QJsonDocument>
#include <QProcess>
#include <QSettings>
#include <vector>
#include <tuple>

PogadeSourceCodeEditor::PogadeSourceCodeEditor(QWidget *parent) :
  QWidget(parent),
  ui(new Ui::PogadeSourceCodeEditor)
{
  ui->setupUi(this);
  ui->buttonViewGraph->setEnabled(false);
  ui->buttonTree->setEnabled(false);
  ui->buttonMakeStandard->setEnabled(false);

  se = new SourceCodeEditor();

  // Set READ ONLY
  se->setReadOnly(true);

  // Enable Code Highlighting
  QsciLexerCPP *lexer = new QsciLexerCPP();
  lexer->setDefaultFont(se->font());
  lexer->setFoldComments(true);
  se->setLexer(lexer);

  // Enable line numbering
  QFontMetrics fontmetrics = QFontMetrics(se->font());
  se->setMarginsFont(se->font());
  se->setMarginWidth(0, fontmetrics.width(QString::number(se->lines())) + 6);
  se->setMarginLineNumbers(0, true);
  se->setMarginsBackgroundColor(QColor("#cccccc"));
  connect(se, SIGNAL(textChanged()), this, SLOT(onTextChanged()));

  // Set Selectec Line
  se->setCaretLineVisible(true);
  se->setCaretLineBackgroundColor(QColor("#ffe4e4"));

  // Set Markers
  se->markerDefine(QsciScintilla::Background, SC_MARK_PSEL_LINE);
  se->setMarkerBackgroundColor(QColor("#a0e0a0"), SC_MARK_PSEL_LINE);
  se->markerDefine(QsciScintilla::SC_MARK_BACKGROUND, SC_MARK_PSEL_SYMB);
  se->setMarkerBackgroundColor(QColor("#80ff80"), SC_MARK_PSEL_SYMB);

  se->markerDefine(QsciScintilla::Background, SC_MARK_PPSEL_LINE);
  se->setMarkerBackgroundColor(QColor("#e0a0a0"), SC_MARK_PPSEL_LINE);
  se->markerDefine(QsciScintilla::SC_MARK_BACKGROUND, SC_MARK_PPSEL_SYMB);
  se->setMarkerBackgroundColor(QColor("#ff8080"), SC_MARK_PPSEL_SYMB);

  se->markerDefine(QsciScintilla::Background, SC_MARK_P_LINE);
  se->setMarkerBackgroundColor(QColor("#b0f0b0"), SC_MARK_P_LINE);
  se->markerDefine(QsciScintilla::SC_MARK_BACKGROUND, SC_MARK_P_SYMB);
  se->setMarkerBackgroundColor(QColor("#90ff90"), SC_MARK_P_SYMB);

  // ******************************************************** //
  connect(se, SIGNAL(doubleClick(int)),
          this, SLOT(lineDoubleClick(int)));

  ui->verticalLayout->addWidget(se);

  connect(ui->comboRevisions, SIGNAL(currentIndexChanged(int)),
          this, SLOT(revisionSelectionChanged(int)));

  updateGUI();
}

PogadeSourceCodeEditor::~PogadeSourceCodeEditor() {
  //PogadeMainWindow *w = (PogadeMainWindow *) this->parentWidget()->parentWidget();
  //w->removeSourceDock(_dock);
  sf->setOpen(false, nullptr);
  delete ui;
  delete se;
}

void PogadeSourceCodeEditor::revisionSelectionChanged(int newSelection) {
    if(_oldComboSelect == newSelection) {
        return;
    }
    if(_oldComboSelect >= 0 && _currentChanged) {
        QMessageBox msgBox;
        msgBox.setText(tr("The File %1 revision %2 ( %3 ) has been modified").arg(sf->name()).arg(sf->getRevInUse()).arg(sf->getRevisionName(sf->getRevInUse())));
        msgBox.setInformativeText(tr("Do you want to save your changes before changing revision?"));
        msgBox.setStandardButtons(QMessageBox::Save | QMessageBox::Discard | QMessageBox::Cancel);
        msgBox.setDefaultButton(QMessageBox::Save);
        int ret = msgBox.exec();
        //Messsaged is shown here
        switch (ret) {
          case QMessageBox::Save:
              saveFile();
          case QMessageBox::Discard:
              sf->setRevInUse(ui->comboRevisions->currentData().toInt());
              se->setText(sf->codeRev(sf->getRevInUse()));
              _currentChanged = false;
              ui->buttonSave->setEnabled(false);
              _oldComboSelect = newSelection;
              break;
          case QMessageBox::Cancel:
              ui->comboRevisions->setCurrentIndex(_oldComboSelect);
              break;
          default:
              // should never be reached
              break;
        }
    }
    else {
        sf->setRevInUse(ui->comboRevisions->currentData().toInt());
        se->setText(sf->codeRev(sf->getRevInUse()));
        _currentChanged = false;
        ui->buttonSave->setEnabled(false);
        _oldComboSelect = newSelection;
    }
}

void PogadeSourceCodeEditor::setDock(QDockWidget * dock) {
  _dock = dock;
}

void PogadeSourceCodeEditor::setSourceFile(PogadeProjectSourceFile* source) {
  sf = source;
  _currentChanged = false;
  updateGUI();
}

void PogadeSourceCodeEditor::updateGUI() {
  if(sf) {
    se->setText(sf->codeRev(sf->getRevInUse()));
    resetComboRevision(sf->getRevInUse());

    se->setReadOnly(!ui->buttonEnableEdit->isChecked());
    _fileLoaded = true;
  }
  else {
    se->setText("");
  }
}

void PogadeSourceCodeEditor::onTextChanged() {
  QFontMetrics fontmetrics = se->fontMetrics();
  se->setMarginWidth(0, fontmetrics.width(QString::number(se->lines())) + 6);
  if(_fileLoaded) {
    //qDebug() << "Text CHANGED!!!";
    _currentChanged = true;
    ui->buttonSave->setEnabled(true);
  }
}

void PogadeSourceCodeEditor::newRevision() {
  PogadeRevisionCreate prc(this);
  prc.setFileName(sf->name());
  prc.setNextRevision(sf->nextRevision());
  connect(&prc, SIGNAL(newRevision(QString)), this, SLOT(createRevision(QString)));
  prc.exec();
}

void PogadeSourceCodeEditor::resetComboRevision(int selectedRevision) {
    int chosen = -1;
    if(sf) {
        QList<unsigned int> revisions = sf->revisions();
        QList<QString> revisionsName  = sf->revisionsNames();
        ui->comboRevisions->clear();
        for(int i=0; i<revisions.size(); ++i) {
            QString line = "Rev " + QString::number(revisions.at(i)) + " - " + revisionsName.at(i);
            ui->comboRevisions->addItem(line, revisions.at(i));
            if((int)revisions.at(i) == selectedRevision)
                chosen = i;
        }
        if(chosen >= 0)
            ui->comboRevisions->setCurrentIndex(chosen);
    }
}

void PogadeSourceCodeEditor::createRevision(QString revName) {
  int rev = ui->comboRevisions->currentData().toInt();
  int newrev = sf->addRevision(rev, revName);

  resetComboRevision(newrev);
}

void PogadeSourceCodeEditor::cleanExit(bool visibility) {
  qDebug() << visibility;
  qDebug() << "Clean Exit";
  qDebug() << this->isVisible();
}

void PogadeSourceCodeEditor::enableEdit(bool enable) {
  se->setReadOnly(!enable);
  ui->buttonMakeStandard->setEnabled(enable);
}

void PogadeSourceCodeEditor::saveFile() {
  ui->buttonSave->setEnabled(false);
  sf->saveCurrentRevision(se->text());
}

bool PogadeSourceCodeEditor::fileChanged() {
  return _currentChanged;
}

PogadeProjectSourceFile* PogadeSourceCodeEditor::sourceFile() {
  return sf;
}

void PogadeSourceCodeEditor::setTDir(QTemporaryDir *tDir) {
  _tDir = tDir;
}

void PogadeSourceCodeEditor::polcaProcessCode() {
  //qDebug() << "POLCA PROCESS!";
  //qDebug() << "In theory we call the polca toolchian now... and wait for the processing";

  //QString fileLocation = "/home/daniel/tp01r0.par";

  QString fileString = _tDir->path() + "/" + sf->name();

  QFile file(fileString);
  bool r = file.open(QFile::WriteOnly | QFile::Text);

  if(r) {
    file.write(sf->codeRev(sf->getRevInUse()).toLatin1());
    file.flush();
  }

  fileString.chop(2);

  //qDebug() << "FILE: " << fileString;
  QStringList args;
  args << fileString;

  QSettings settings;
  QProcess tool;
  //qDebug() << "Tool: " << settings.value("PTReader", POLCATOOLREADER).toString();
  tool.start(settings.value("PTReader", POLCATOOLREADER).toString(), args);


  // Launch wait window
  toolsWait *tw = new toolsWait();
  tw->show();

  if (!tool.waitForStarted(-1)) {
    //qDebug() << "Wait For Started Failed";
  }

  while(!tool.waitForFinished(10)) {
    QCoreApplication::processEvents();
    //qDebug() << "Loop";
  }

  /*
  if (!tool.waitForFinished(-1)) {
    qDebug() << "Wait For Finished Failed";
  }
  */

  // Clouse wait window
  delete tw;

  QByteArray _data =  tool.readAllStandardOutput();
  QString data = _data;

  //qDebug() << "JSON" << data;

  loadPolcaProcessingData(data);
  //loadPolcaProcessing(fileLocation);

}

void PogadeSourceCodeEditor::loadPolcaProcessingData(QString data) {
  QJsonDocument doc = QJsonDocument::fromJson(data.toLatin1());
  if(doc.isEmpty()) {
    ui->buttonViewGraph->setEnabled(false);
    ui->buttonTree->setEnabled(false);
    return;
  }

  ui->buttonViewGraph->setEnabled(true);
  ui->buttonTree->setEnabled(true);
  QJsonObject obj = doc.object();
  QJsonArray pragmas = obj.value("pragmas").toArray();

  QList<pragma_t> plist;

  // Get all Pragmas
  for(QJsonValue p : pragmas) {
    pragma_t _p;
    _p.code       = p.toObject().value("code").toString();
    _p.endCol     = p.toObject().value("endCol").toInt();
    _p.endLine    = p.toObject().value("endLine").toInt();
    _p.len        = p.toObject().value("len").toInt();
    _p.pragma     = p.toObject().value("pragma").toString();
    _p.pragmaLine = p.toObject().value("pragmaLine").toInt();
    _p.start      = p.toObject().value("start").toInt();
    _p.startCol   = p.toObject().value("startCol").toInt();
    _p.startLine  = p.toObject().value("startLine").toInt();

    plist.append(_p);
  }


  // Set Pragmas to Scopes
  /*
  for(pragma_t p : plist) {
    qDebug() << p.pragma;
    qDebug() << p.startLine << " - " << p.endLine;
  }
  qDebug() << "---------------------";
  */

  for(pragma_t p : plist) {
    PolcaScope *ps;
    int newscope = 0;

    ps = sf->findScope(p.startLine, p.endLine);
    if(!ps){
      ps = new PolcaScope();
      newscope = 1;

      ps->setId(PolcaScope::idNext());
      PolcaScope::idNextIncrease();
      ps->setCodeLineStart(p.startLine);
      ps->setCodeLineEnd(p.endLine);

    }

    PolcaPragma pp;
    pp.setLineStart(p.pragmaLine);
    pp.setLineEnd(p.pragmaLine);
    pp.setText(p.pragma);


    ps->pragmaAdd(pp);

    if(newscope) {
      sf->addScope(*ps);
      delete ps;
    }
  }

  sf->automaticNamesScopes();
  sf->generateTreeScopes();
  sf->findRootScopes();
  showPragmas();
}

/*
void PogadeSourceCodeEditor::loadPolcaProcessing(QString file) {
  //qDebug() << file;
  QFile f(file);
  f.open(QIODevice::ReadOnly | QIODevice::Text);

  QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
  f.close();
  //qDebug() << "JSON file empty? " << doc.isNull();
  //qDebug() << "JSON content: " << doc.toJson();


  if(!doc.isEmpty()) {
    ui->buttonViewGraph->setEnabled(true);
    ui->buttonTree->setEnabled(true);
    QJsonObject obj = doc.object();
    QJsonArray scopes = obj.value("polcaScopes").toArray();
    for(QJsonValue s : scopes) {
      PolcaScope ps;

      //qDebug() << "---------------";
      //qDebug() << s;
      ps.setId(s.toObject().value("scopeId").toInt());
      ps.setName(s.toObject().value("name").toString());
      ps.setCodeLineStart(s.toObject().value("codeLineStart").toInt());
      ps.setCodeLineEnd(s.toObject().value("codeLinesEnd").toInt());


      QJsonArray children = s.toObject().value("children").toArray();
      for(QJsonValue c : children) {
        ScopeChildInfo sci;
        sci.setId(c.toObject().value("id").toInt());

        QJsonArray cins = c.toObject().value("in").toArray();
        for(QJsonValue cin : cins) {
          int n = cin.toInt();
          sci.addInChildren(n);
        }
        QJsonArray couts = c.toObject().value("out").toArray();
        for(QJsonValue cout : couts) {
          int n = cout.toInt();
          sci.addOutChildren(n);
        }

        ps.addChildScope(sci);
      }

      QJsonArray pragmas = s.toObject().value("pragmas").toArray();
      for(QJsonValue p : pragmas) {
        PolcaPragma pp;
        pp.setText(p.toObject().value("text").toString());
        pp.setLineStart(p.toObject().value("lineStart").toInt());
        pp.setLineEnd(p.toObject().value("lineEnd").toInt());

        ps.pragmaAdd(pp);
      }

      //TODO: do we need to check a valid sf?
      sf->addScope(ps);
      sf->setValidScope(true);
    }
    //sf->analyzeCurrentScopes();
    sf->findRootScopes();
    showPragmas();
  }
  else {
    ui->buttonViewGraph->setEnabled(false);
    ui->buttonTree->setEnabled(false);
  }
}
*/

void PogadeSourceCodeEditor::showPragmas() {
  // Remove all markers and add the new ones
  se->markerDeleteAll(SC_MARK_PSEL_LINE);
  se->markerDeleteAll(SC_MARK_PSEL_SYMB);
  se->markerDeleteAll(SC_MARK_PPSEL_LINE);
  se->markerDeleteAll(SC_MARK_PPSEL_SYMB);
  se->markerDeleteAll(SC_MARK_P_LINE);
  se->markerDeleteAll(SC_MARK_P_SYMB);


  if(sf && sf->validScope()) {
    std::vector<PolcaScope> scopes = sf->getScopes();

    for(PolcaScope s : scopes) {
      std::vector<PolcaPragma> pragmas = s.getPragmas();

      for(PolcaPragma p : pragmas) {
        auto ls = p.lineStart()-1;
        auto le = p.lineEnd()-1;
        for(auto i = ls; i<=le; ++i) {
          se->markerAdd(i, SC_MARK_P_LINE);
          se->markerAdd(i, SC_MARK_P_SYMB);
        }
      }
    }
  }
}

void PogadeSourceCodeEditor::lineDoubleClick(int line) {
  //qDebug() << "Double Click line: " << line << " + 1";
  PolcaScope ps;
  PolcaPragma pp;
  bool valid = false;

  if(sf && sf->validScope()) {
    std::tie(valid, ps, pp) = sf->findScopeAndPragmaFromLine(line+1);
    if(valid) {
      selectedPragmaAndScope(ps, pp);
    }
    else {
      //qDebug() << "Pragma not found at line " << line << " + 1";
    }
  }
}

void PogadeSourceCodeEditor::selectedScope(PolcaScope ps) {
  // Remove all markers and add the new ones
  se->markerDeleteAll(SC_MARK_PSEL_LINE);
  se->markerDeleteAll(SC_MARK_PSEL_SYMB);
  se->markerDeleteAll(SC_MARK_PPSEL_LINE);
  se->markerDeleteAll(SC_MARK_PPSEL_SYMB);


  std::vector<PolcaPragma> pragmas = ps.getPragmas();
  for(PolcaPragma p : pragmas) {
    auto pls = p.lineStart() -1;
    auto ple = p.lineEnd()   -1;
    for(auto i = pls; i<=ple; ++i) {
      se->markerAdd(i, SC_MARK_PSEL_LINE);
      se->markerAdd(i, SC_MARK_PSEL_SYMB);
    }
  }

  auto sls = ps.codeLineStart() -1;
  auto sle = ps.codeLineEnd()   -1;
  for(auto i = sls; i<=sle; ++i) {
    se->markerAdd(i, SC_MARK_PPSEL_LINE);
    se->markerAdd(i, SC_MARK_PPSEL_SYMB);
  }

  //TODO: different color for pragmas inside selected scopes

  emit scopeSelectedDown(ps.id());
}

void PogadeSourceCodeEditor::selectedPragmaAndScope(PolcaScope ps, PolcaPragma pp) {
  //qDebug() << "----------------------";
  //qDebug() << pp.text();
  //qDebug() << ps.name();

  // Remove all markers and add the new ones
  se->markerDeleteAll(SC_MARK_PSEL_LINE);
  se->markerDeleteAll(SC_MARK_PSEL_SYMB);
  se->markerDeleteAll(SC_MARK_PPSEL_LINE);
  se->markerDeleteAll(SC_MARK_PPSEL_SYMB);

  auto pls = pp.lineStart() -1;
  auto ple = pp.lineEnd()   -1;
  for(auto i = pls; i<=ple; ++i) {
    se->markerAdd(i, SC_MARK_PSEL_LINE);
    se->markerAdd(i, SC_MARK_PSEL_SYMB);
  }


  auto sls = ps.codeLineStart() -1;
  auto sle = ps.codeLineEnd()   -1;
  for(auto i = sls; i<=sle; ++i) {
    se->markerAdd(i, SC_MARK_PPSEL_LINE);
    se->markerAdd(i, SC_MARK_PPSEL_SYMB);
  }

  //TODO: different color for pragmas inside selected scopes

  emit scopeSelectedDown(ps.id());
}

void PogadeSourceCodeEditor::viewGraph() {
  emit createNV(sf);
}

void PogadeSourceCodeEditor::viewTree() {
  emit createST(sf);
}

void PogadeSourceCodeEditor::scopeSelectedUPProcess(int id) {
  //qDebug() << "SCE Sel: " << id;
  if(sf) {
    PolcaScope *ps = sf->findScope(id);
    selectedScope(*ps);
  }
}

void PogadeSourceCodeEditor::makeStandard() {
  if(sf) {
    QString fname = sf->getProject()->workingDir() + QDir::separator()+"workfile.c";
    QFile file(fname);
    if (file.open(QIODevice::WriteOnly)) {
      QTextStream stream(&file);
      stream << se->text();
      file.close();

      QStringList args;
      args << fname;
      QProcess tool;
      QSettings settings;
      QString polcaToolCommand = settings.value("PTPretty", POLCATOOLPRETTY).toString();
      tool.start(polcaToolCommand, args);

      while(!tool.waitForFinished(POLCATOOLWAITTIME)) {
        qApp->processEvents();
      }

      if(!tool.exitCode()) {
        // Tool returned success!
        se->setText(tool.readAllStandardOutput());
      }
      else {
        // Tool returned error
        QMessageBox::critical(this, tr("Error"), tr("Error executing POLCA tools"));
      }
    }
  }
}