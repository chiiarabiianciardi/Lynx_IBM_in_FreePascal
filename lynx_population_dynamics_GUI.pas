{}
unit lynx_population_dynamics_GUI;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, TAGraph, TASeries, Forms, Controls, Graphics,
  Dialogs, StdCtrls, ExtCtrls, Math, LCLType,            //Math not used
  lynx_define_units, general_functions, lynx_input_output_functions,
  lynx_vital_rates;

type
Tspatial_Form = class(TForm)
    Chart1: TChart;
    Chart1LineSeries1: TLineSeries;
    Chart1LineSeries2: TLineSeries;
    Edit1: TEdit;
    Edit10: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    Edit5: TEdit;
    Exit_Button: TButton;
    Abort_Button: TButton;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Panel1: TPanel;
    Run_Button: TButton;
    procedure Abort_ButtonClick(Sender: TObject);
    procedure Exit_ButtonClick(Sender: TObject);
    procedure Run_ButtonClick(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
    procedure Pop_dynamics_GUI;
  end;

var
  spatial_Form: Tspatial_Form;

implementation

{$R *.lfm}

{ Tspatial_Form }


procedure Startpopulation;
var
  a, i, k: integer;
  tmic: real;
begin
  Population := TList.Create;

  //Create/initiate the Famtree (array of array)
  SetLength(Famtree, n_ini);

  //Initialization of UniqueID at 0 (the first ind will hav an ID of 0)
  UniqueIDnext:= 0;

  with population do
  begin
    for a := 1 to n_ini do
    begin
      new(Individual);

      Individual^.age := random(3) + 3;   {alternative: Individual^.age:=0; }

      if random < 0.5 then Individual^.sex := 'f'
      else
      Individual^.sex := 'm';
      Individual^.status := 1;
      Individual^.UniqueID :=UniqueIDnext;
      Individual^.IC := 0;

      Individual^.Coor_X := 130;
      Individual^.Coor_Y := 120;

      setLength(Individual^.TerritoryX, Tsize);
      setLength(Individual^.TerritoryY, Tsize);
      ArrayToNegOne(Individual^.TerritoryX);
      ArrayToNegOne(Individual^.TerritoryY);

      Individual^.mov_mem := random(8) + 1;
      Individual^.homeX := Individual^.Coor_X;
      Individual^.homeY := Individual^.Coor_Y;
      Individual^.return_home := False;

      Individual^.DailySteps := 0;
      Individual^.DailyStepsOpen := 0;

      setLength(Individual^.Genome, 25, 2);


      for i := 1 to 24 do
      begin
        for k := 0 to 1 do
        begin
          tmic := random;
          if tmic < 0.25 then
            Individual^.Genome[i, k] := 1
          else if tmic < 0.5 then
            Individual^.Genome[i, k] := 2
          else if tmic < 0.75 then
            Individual^.Genome[i, k] := 3
          else
            Individual^.Genome[i, k] := 4;
          end;
        end;

      Population.add(Individual);

      SetLength(Famtree, n_ini, 4);
      Famtree[Individual^.UniqueID,0]:=Individual^.UniqueID;  //UniqueID
      Famtree[Individual^.UniqueID,1]:=0;                     //IC
      Famtree[Individual^.UniqueID,2]:= -1;                   //FatherID
      Famtree[Individual^.UniqueID,3]:= -1;                   //MotherID


      UniqueIDnext:= UniqueIDnext+1


    end;
  end;
end;


procedure Tspatial_Form.Pop_dynamics_GUI;
var
  a, b, xy, day, Tcheck, current_sim: integer;
begin
  current_sim:= 1;
  with population do
  begin
    for a := 1 to max_years do
    begin
      day := 0;  // Start the year
      while day < 366 do
      begin
        day := day + 1;
        populationsize := population.Count;

        UpdateAbundanceMap;

        if day = 90 then
          if populationsize > 2 then

          reproduction;                 // Reproduction happens at the end of March

        Dispersal(day);                 // Dispersal of surviving individuals (also includes dispersion start for subadults)

        survival;                       // Determine which individuals survive this day
      end;

      populationsize := population.Count;
      if populationsize > 0 then
      begin
        for b := 0 to populationsize - 1 do
        begin
          Individual := Items[b];
          Individual^.Age := Individual^.Age + 1;
          if (Individual^.Status = 2) and (Individual^.Age < max_rep_age) then
          begin
          Tcheck := 0;
          for xy := 0 to Tsize - 1 do
          begin
            if ((Individual^.TerritoryX[xy] > 0) and (Individual^.TerritoryY[xy] > 0)) then Tcheck := Tcheck + 1;
          end;
          if Tcheck = Tsize then Individual^.Status := 3;
          end;
        end;
      end;

      {ploting pop size}
      if max_pop_size < populationsize then max_pop_size := populationsize;
      if max_pop_size > Chart1.extent.YMax then
      begin
        Chart1.extent.YMax := max_pop_size;
        application.ProcessMessages;
      end;
      pop_size[a] := populationsize;
      sum_pop_size[a] := sum_pop_size[a] + populationsize;
      if populationsize > 0 then n_sim_no_ext[a] := n_sim_no_ext[a] + 1;
      {plot trajectory}
      Chart1LineSeries1.addxy(a, populationsize);

      if (a <= 5) then
      begin
         WritePopulationToCSV(population,'PopulationYear.csv', current_sim, a );
      end;

    end;
    if populationsize = 0 then N_extint := N_extint + 1;

    WriteMapCSV('FemalesMap_status.csv', Femalesmap, MapdimX, MapdimY, 0);
    WriteMapCSV('FemalesMap_age.csv', Femalesmap, MapdimX, MapdimY, 1);
    WriteMapCSV('MalesMap_status.csv', Malesmap, MapdimX, MapdimY, 0);
    WriteMapCSV('MalesMap_age.csv', Malesmap, MapdimX, MapdimY, 1);
    WriteFamtreeToCSV('Famtree.csv');

  end;
end;

procedure Tspatial_Form.Run_ButtonClick(Sender: TObject);
var
  a, b: integer;
  t: string;      //not used
begin
  randomize; {initialize the pseudorandom number generator}

  paramname := Edit3.Text;
  ShowMessage('DEBUG: Paramname = ' + paramname);
  ReadParameters(paramname);

  {These values should overwrite the values in the file with the input from the GUI}
  val(Edit1.Text, n_ini);  {read parameter values from the form}
  val(Edit2.Text, max_years);
  val(Edit5.Text, n_sim);


  mapname :='input_data/old_donana.txt';

  readmap(mapname);


  SetLength(MalesMap, Mapdimx + 1, Mapdimy + 1, 2);
  SetLength(FemalesMap, Mapdimx + 1, Mapdimy + 1, 2);

  N_extint := 0;

  if not DirectoryExists('output_data') then
    MkDir('output_data');

  try
  AssignFile(to_file_out, 'output_data/popsize.txt');
  Rewrite(to_file_out); {create txt file}

  for a := 1 to max_years do sum_pop_size[a] := 0;
  for a := 1 to max_years do n_sim_no_ext[a] := 0;

  // Calculate array of step probabilities (here once) to be used in dispersal procedure later
  Step_probabilities;

  for current_sim := 1 to n_sim do
  begin

    max_pop_size := 0;
    Startpopulation; {call the procedure to initialize your population}
    Pop_dynamics_GUI;    {call the procedure to run the population dynamics}


    {plot population trayectories}
    Chart1LineSeries1.Clear;
    Chart1LineSeries2.Clear;

    for b := 1 to max_years do Chart1LineSeries1.addxy(b, pop_size[b]);
    application.ProcessMessages;
    if (current_sim > 1) then
      if (n_sim > 1) and (n_extint <> n_sim) then
        for b := 1 to max_years do
          Chart1LineSeries2.addxy(b, sum_pop_size[b] / current_sim);

    {save the results to a text file}
    append(to_file_out);
    for b := 1 to max_years do
      writeln(to_file_out, current_sim, ' ', b, ' ', pop_size[b]);
    {we save all simulations}
    if current_sim = n_sim then
      for b := 1 to max_years do
        writeln(to_file_out, 'avg', ' ', b, ' ', sum_pop_size[b] / current_sim);
    {and the average of all simulations}
    end;
  finally
    CloseFile(to_file_out);


  end;

end;

procedure Tspatial_Form.Exit_ButtonClick(Sender: TObject);
begin
  Close;
end;

procedure Tspatial_Form.Abort_ButtonClick(Sender: TObject);
begin
  halt;
end;

end.

