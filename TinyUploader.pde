/**
 * TinyUploader  -- Program an ATtiny using the TinyISP programmer.
 * -------------
 *
 * Steps to build application:
 *  1. "Export Application" from within Processing
 *  2. Run "./package-after-export.sh" on command-line
 *
 *
 * 2010, Tod E. Kurt, http://thingm.com/
 * 2010, modified by David A. Mellis
 *
 * 
 * Avrdude commands for uploading when using USBtiny / TinyISP:
 *  avrdude -p attiny45 -c usbtiny \
 *  -U flash:w:/Users/tod/projects/projects_todbot/blinkm/blinkmv1/blinkmv1.hex
 *
 * avrdude -p attiny45 -c usbtiny \
 *  -U eeprom:w:/Users/tod/projects/projects_todbot/blinkm/blinkmv1/blinkmv1.eep
 *
 * avrdude -p attiny45 -c usbtiny -U lfuse:w:0xDD:m
 *
 * and that can all be one command.
 *
 */

import java.awt.*;
import java.awt.event.*;
import javax.swing.*;
import javax.swing.border.*;      // for silly borders on buttons
import javax.swing.plaf.metal.*;
import java.util.*;

import processing.serial.*;

boolean debug = true;

public static class Firmware  {
  public String name;    // name of firmware
  public String hex;     // filename of firmware hex 
  public String eep;     // filename of EEPROM 
  public String lfuse;   // fuse settings
  public String hfuse;   // fuse settings
  public String efuse;   // fuse settings
  public Firmware(String n, String h, String e, 
                  String lf, String hf, String ef) {
    name = n; hex = h; eep = e; lfuse = lf; hfuse = hf; efuse = ef;
  }
}

// the supported track durations
public static final Firmware[] firmwares = new Firmware [] {
  new Firmware( "Touch", 
                "touch.hex", 
                "touch.eep",
                "0x62",
                "0xDF",
                "0xFF"
                ),
  new Firmware( "Twinkle", 
                "twinkle.hex", 
                "twinkle.eep",
                "0x62",
                "0xDF",
                "0xFF"
                ),
  new Firmware( "Sweep", 
                "sweep.hex", 
                "twinkle.eep",
                "0x62",
                "0xDF",
                "0xFF"
                ),
  new Firmware( "Back & Forth", 
                "back_and_forth.hex", 
                "twinkle.eep",
                "0x62",
                "0xDF",
                "0xFF"
                ),
  new Firmware( "Flash", 
                "flash.hex", 
                "twinkle.eep",
                "0x62",
                "0xDF",
                "0xFF"
                ),
};

public static final String mcuNames[] = { "ATtiny45", "ATtiny85" };


String mcuName;
String portName;
String firmName;

ReflashDialog reflashDialog;

// Processing's setup()
void setup() {

}

// Procesing's draw()
void draw() {
  //
  if( frameCount==1  ) {
    super.frame.setVisible(false);  // turn off Processing's frame
    super.frame.toBack();

    //PApplet p = this;
    println("showDialog");
    javax.swing.SwingUtilities.invokeLater(new Runnable() {
        public void run() {
          try{ Thread.sleep(500); } catch(Exception e){} // wait to avoid assert
          reflashDialog = new ReflashDialog();
        }
      } );
  }

}


// 
// Runs a thread separate from the Swing GUI or Processing's draw()
//
class Programmer implements Runnable {

  public void run() {
    reflashBlinkM();
  }

  //
  //
  //
  String runAvrdudeCmd( String[] cmd  ) {
    String rc = "";
    
    try { 
      Process process=new ProcessBuilder(cmd).redirectErrorStream(true).start();
      InputStream is = process.getInputStream();
      BufferedReader br = new BufferedReader(new InputStreamReader(is));
      
      //System.out.printf("Output of running %s is:", Arrays.toString(cmd));
      String s = "";
      for( int i=0; i< cmd.length;i++)
        s += cmd[i]+" ";
      println("avrdude cmd:\n"+s); // always print out avrdude command to console
      
      String line;
      while ((line = br.readLine()) != null) {
        rc += line;
        if( line.indexOf("writing flash") != -1 ) {
          reflashDialog.updateMsg("Writing flash...");
        } else if( line.indexOf("reading on-chip flash") != -1 ) { 
          reflashDialog.updateMsg("Verifying flash...");
        } else if( line.indexOf("writing eeprom") != -1 ) { 
          reflashDialog.updateMsg("Writing eeprom...");
        } else if( line.indexOf("reading on-chip eeprom") != -1 ) {
          reflashDialog.updateMsg("Verifying eeprom...");
        } else if( line.indexOf("writing lfuse") != -1 ) {
          reflashDialog.updateMsg("Writing lfuse...");
        } else if( line.indexOf("verifying lfuse") != -1 ) {
          reflashDialog.updateMsg("Verifying lfuse...");
        } else if( line.indexOf("writing hfuse") != -1 ) {
          reflashDialog.updateMsg("Writing hfuse...");
        } else if( line.indexOf("verifying hfuse") != -1 ) {
          reflashDialog.updateMsg("Verifying hfuse...");
        } else if( line.indexOf("writing efuse") != -1 ) {
          reflashDialog.updateMsg("Writing efuse...");
        } else if( line.indexOf("verifying efuse") != -1 ) {
          reflashDialog.updateMsg("Verifying efuse...");
        }
        if( debug ) println(":"+line);
        //if( reflashing == false) { 
        //  return "canceled";
        //}
      }
    } catch( IOException ioe ) { 
      ioe.printStackTrace();
    }
    
    return rc;
  }


  //
  // This is run outside the normal Swing GUI thread
  //
  void reflashBlinkM() {
    reflashDialog.setReflashing(true);
    reflashDialog.updateMsg("Reflashing '"+firmName+"'...");
    
    String cmdpath = sketchPath;
    String binpath = "";
    String confpath = "";
    String sep = File.separator;

    if( platform == MACOSX ) { 
      cmdpath += "/TinyUploader.app/Contents/Resources/Java/tools";
      File f = new File(cmdpath);
      if( !f.exists() ) {              // in a sketch, not an exported app
        cmdpath = sketchPath + "/tools";
      }
      binpath = cmdpath + "/bin-macosx/avrdude";
    }
    else if( platform == WINDOWS ) {
      cmdpath += "\\tools";  // FIXME: verify this
      binpath = cmdpath + "\\bin-windows\\avrdude.exe";
    }
    
    confpath = cmdpath + sep + "etc" + sep + "avrdude.conf";
    
    int fwid = -1;
    for( int i = 0; i<firmwares.length; i++ ) {
      if( firmwares[i].name.equals(firmName) ) fwid = i;
    }
    Firmware fw = firmwares[fwid];  // FIXME: check fwid not -1
    
    String hexpath = cmdpath +sep+ "firmwares" +sep+ fw.hex;
    String eeppath = cmdpath +sep+ "firmwares" +sep+ fw.eep;
    
    String[] cmd = new String[] { binpath, 
                                  "-C", confpath,
                                  "-c", "usbtiny", 
                                  "-p", mcuName,
                                  "-U", "flash:w:"+hexpath+":i",
//                                  "-U", "eeprom:w:"+eeppath+":i",
                                  "-U", "lfuse:w:"+fw.lfuse+":m",
                                  "-U", "hfuse:w:"+fw.hfuse+":m",
                                  "-U", "efuse:w:"+fw.efuse+":m",
    };

    // run the actual avrdude command
    String output = runAvrdudeCmd( cmd );
    
    if( output.indexOf("can't open device") != -1 ) {
      reflashDialog.updateErr("Can't open serial device, try another");
    }
    else if( output.indexOf("Device is not responding") != -1 ) {
      reflashDialog.updateErr("Programmer not responding. Check connections.");
    }
    else if( output.indexOf("programmer is not responding") != -1 ) {
      reflashDialog.updateErr("Programmer not responding.  Is it plugged in?");
    }
    else if( output.indexOf("Expected signature") != -1 ) { 
      reflashDialog.updateErr("Wrong chip type detected.");
    }
    else if( output.indexOf("verification error") != -1 ) {
        reflashDialog.updateErr("Verification error, bad wiring?");
    }
    else if( output.indexOf("Yikes!  Invalid device signature.") != -1 ){
      reflashDialog.updateErr("No chip detected. Check connections.");
    }
    else if ( output.indexOf("Could not find USB device 0x1781/0xc9f") != -1 ) {
      reflashDialog.updateErr("Couldn't find programmer.");
    }
    else if ( output.indexOf("initialization failed") != -1 ) {
      reflashDialog.updateErr("Couldn't talk to chip.");
    }
    else if ( output.indexOf("can't open input file") != -1 ) {
      reflashDialog.updateErr("Can't find that program.");
    }
    else if( output.indexOf("done.") != -1 ) {
      reflashDialog.updateMsg("Uploading Done!");
    }

    reflashDialog.setReflashing(false);
  }

} // class Programmer


//
// Sets up the GUI
//
public class ReflashDialog extends JDialog { 

  JComboBox portChoices;
  JComboBox mcuChoices;
  JComboBox firmChoices;
  JLabel msgbText;
  JButton reflashButton;

  boolean reflashing = false;

  //
  public ReflashDialog() {
    super();

    try {  // use a Swing look-and-feel that's the same across all OSs
      MetalLookAndFeel.setCurrentTheme(new DefaultMetalTheme());
      UIManager.setLookAndFeel( new MetalLookAndFeel() );
    } catch(Exception e) { }  // don't really care if it doesn't work

    openReflashDialog();
  }


  public void openReflashDialog() {

//    String[] portNames = listPorts();
    String[] firmNames = getFirmwareNames();

    String lastMcuName = mcuName;
    String lastPortName = portName;
    String lastFirmName = firmName;

    int fidx = 0, midx = 0;
//    for( int i=0; i<portNames.length; i++) 
//      if( portNames[i].equals(lastPortName) ) pidx = i;
    for( int i=0; i<mcuNames.length; i++)
      if( mcuNames[i].equals(lastMcuName) ) midx = i;
    for( int i=0; i<firmNames.length; i++)
      if( firmNames[i].equals(lastFirmName) ) fidx = i;

//    portChoices = new JComboBox(portNames);
//    portChoices.setSelectedIndex( pidx );

    mcuChoices = new JComboBox(mcuNames);
    mcuChoices.setSelectedIndex( midx );

    firmChoices = new JComboBox(firmNames);
    firmChoices.setSelectedIndex( fidx );

    JPanel msgtPanel = new JPanel();
    JPanel msgbPanel = new JPanel();
    JPanel ctrlPanel = new JPanel();
    JPanel firmPanel = new JPanel();
    JPanel portPanel = new JPanel();
    JPanel statPanel = new JPanel();
    JPanel buttPanel = new JPanel();
    JPanel mainPanel = new JPanel();

    //ctrlPanel.setLayout( new BorderLayout() );
    msgtPanel.setLayout( new BorderLayout() );
    msgbPanel.setLayout( new BorderLayout() );
    ctrlPanel.setLayout( new BoxLayout(ctrlPanel,BoxLayout.Y_AXIS) );
    firmPanel.setLayout( new BorderLayout() );
    portPanel.setLayout( new BorderLayout() );
    mainPanel.setLayout( new BorderLayout() );

    ctrlPanel.setBorder(new EmptyBorder(15,15,15,15));
    firmPanel.setBorder(new EmptyBorder(15,15,15,15));
    portPanel.setBorder(new EmptyBorder(15,15,15,15));
    mainPanel.setBorder(new EmptyBorder(15,15,15,15));
    

    JLabel msgtText = new JLabel("Welcome to Tiny Uploader Tool");
    msgbText = new JLabel("<html>...</html>");
    JLabel firmText = new JLabel("Select program");
    JLabel mcuText = new JLabel("Select microcontroller");
//    JLabel portText = new JLabel("Select port of ArduinoISP");

    reflashButton = new JButton("Upload");

    msgtPanel.add( msgtText );
    msgbPanel.add( msgbText );

    firmPanel.add( firmText, BorderLayout.NORTH );
    firmPanel.add( firmChoices );
    portPanel.add( mcuText, BorderLayout.NORTH );
    portPanel.add( mcuChoices );
//    portPanel.add( portText, BorderLayout.NORTH );
//    portPanel.add( portChoices );
    buttPanel.add( reflashButton );

    ctrlPanel.add( firmPanel );
    ctrlPanel.add( portPanel );
    ctrlPanel.add( buttPanel );

    mainPanel.add( msgtPanel, BorderLayout.NORTH );
    mainPanel.add( ctrlPanel, BorderLayout.CENTER );
    mainPanel.add( msgbPanel, BorderLayout.SOUTH );

    reflashButton.addActionListener( new ActionListener() { 
        public void actionPerformed(ActionEvent e) {
          firmName = (String) firmChoices.getSelectedItem();
          mcuName = (String) mcuChoices.getSelectedItem();
          //portName = (String) portChoices.getSelectedItem();

          setReflashing(true);
          new Thread( new Programmer() ).start();
          
        }
      });
    
    JDialog dialog = new JDialog();
    dialog.setTitle("Upload to ATtiny");

    // handle window close events
    dialog.addWindowListener(new WindowAdapter() {
        public void windowClosing(WindowEvent e) {
          dispose();            // close mainframe
          //appletRef.destroy();  // close processing window as well
          //appletRef.frame.setVisible(false);
          System.exit(0);
        }
      }); 

    dialog.getContentPane().add(mainPanel); // jdialog has limited container 
    dialog.pack();
    dialog.setResizable(false);
    dialog.setLocationRelativeTo(null); // center it on BlinkMSequencer
    dialog.setVisible(true);

  }
  
  void updateErr(String s) {
    if(debug) println(s);
    msgbText.setText("<html><font color='red'>"+s+"</font></html>");
  }
  
  void updateMsg(String s) {
    if(debug) println(s);
    msgbText.setText("<html>"+s+"</html>");
  }

  void setReflashing(boolean b) { 
      reflashing = b;
      reflashButton.setEnabled( !b );
  }
  boolean isReflashing() {
      return reflashing;
  }

  // Return a list of potential ports
  // they should be ordered by best to worst (but are not right now)
  // this can't be static as a .pde, sigh.
  public String[] listPorts() {
    String[] a = Serial.list();
    String osname = System.getProperty("os.name");
    if( osname.toLowerCase().startsWith("windows") ) {
      // reverse list because Arduino is almost always highest COM port
      for(int i=0;i<a.length/2;i++){
        String t = a[i]; a[i] = a[a.length-(1+i)]; a[a.length-(1+i)] = t;
      }
    }
    if( debug ) { 
      for( int i=0;i<a.length;i++){
        println(i+":"+a[i]);
      }
    }
    return a;
  }

  public String[] getFirmwareNames() {
    String[] names = new String[firmwares.length];
    for( int i=0; i< firmwares.length; i++) {  
      names[i] = firmwares[i].name;
    }
    return names;
  }

}


/**
 * will not use this, but it shows how static hashmaps are done
 *
public static class OSstuff { 
  public String avrdude; // name of avrdude
  public String sep;     // file separator
  public OSstuff( String a, String s ) { 
    avrdude = a; sep = s;
  }
}
//public final HashMap<OSstuff> osdeets = new HashMap<OSstuff>();
public static final HashMap osdeets = new HashMap();
static {
  osdeets.put( "macosx",  new OSstuff("avrdude","/") );
  osdeets.put( "windows", new OSstuff("avrdude.exe","\\") );
}
*/


/*
//
void debug(String s) {
  debug( s,null);
}
//
void debug(String s1, Object s2) {
  String s = s1;
  if( s2!=null ) s = s1 + " : " + s2;
  if(debug) println(s);
  //lastMsg = s1;
}


*/
