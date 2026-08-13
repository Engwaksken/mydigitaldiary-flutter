import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/financial_planner_service.dart';
import '../services/api_client.dart';

class FinancialPlannerScreen extends StatefulWidget {
  const FinancialPlannerScreen({super.key});
  @override State<FinancialPlannerScreen> createState() => _FinancialPlannerScreenState();
}

class _FinancialPlannerScreenState extends State<FinancialPlannerScreen> {
  final _service = FinancialPlannerService();
  FinancialPlannerSnapshot? _data; bool _loading = true; String? _error;
  late DateTime _start = DateTime(DateTime.now().year, DateTime.now().month - 5, 1);
  late DateTime _end = DateTime.now();
  String _d(DateTime x) => DateFormat('yyyy-MM-dd').format(x);
  String _money(dynamic v) => NumberFormat('#,##0').format((v as num?)?.toDouble() ?? double.tryParse('$v') ?? 0);

  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async { setState((){_loading=true;_error=null;}); try { final x=await _service.load(startDate:_d(_start),endDate:_d(_end)); if(mounted)setState(()=>_data=x); } on ApiException catch(e){if(mounted)setState(()=>_error=e.message);} finally {if(mounted)setState(()=>_loading=false);} }
  Future<void> _pick(bool start) async { final d=await showDatePicker(context:context,initialDate:start?_start:_end,firstDate:DateTime(2000),lastDate:DateTime.now().add(const Duration(days:365))); if(d!=null){setState((){if(start) {
    _start=d;
  } else {
    _end=d;
  }});_load();} }

  @override Widget build(BuildContext context){
    final m=_data?.metrics;
    return Scaffold(appBar:AppBar(title:const Text('Financial Planner')),body:_loading?const Center(child:CircularProgressIndicator()):_error!=null?Center(child:Text(_error!)):RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('Retirement planner',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
      const SizedBox(height:6),const Text('Uses your linked income, expenses, budgets, savings and debts for the selected period. Projections are estimates, not guarantees.'),
      const SizedBox(height:12),Row(children:[Expanded(child:OutlinedButton.icon(onPressed:()=>_pick(true),icon:const Icon(Icons.date_range),label:Text(_d(_start)))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:()=>_pick(false),icon:const Icon(Icons.event),label:Text(_d(_end))))]),
      const SizedBox(height:16),if(m!=null) GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,childAspectRatio:1.55,crossAxisSpacing:10,mainAxisSpacing:10,children:[
        _card('Income','UGX ${_money(m['income'])}',Icons.trending_up),_card('Expenses','UGX ${_money(m['expenses'])}',Icons.receipt_long),_card('Savings','UGX ${_money(m['saved'])}',Icons.savings),_card('Outstanding debt','UGX ${_money(m['outstandingDebt'])}',Icons.credit_card),
        _card('Projected savings','UGX ${_money(m['future'])}',Icons.insights),_card('Retirement target','UGX ${_money(m['target'])}',Icons.flag),_card('Funding progress','${((m['funding'] as num?)?.toDouble()??0).toStringAsFixed(1)}%',Icons.donut_large),_card('Years remaining','${m['years'] ?? 0}',Icons.hourglass_bottom),
      ]),
      const SizedBox(height:16),if(_data!=null) ElevatedButton.icon(onPressed:_editAssumptions,icon:const Icon(Icons.tune),label:const Text('Edit retirement assumptions')),
    ])));
  }
  Widget _card(String t,String v,IconData i)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(i),const Spacer(),Text(v,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),Text(t,style:const TextStyle(fontSize:12))])));
  Future<void> _editAssumptions() async { final p=_data!.profile; final age=TextEditingController(text:'${p['current_age']??30}'),ret=TextEditingController(text:'${p['retirement_age']??60}'),current=TextEditingController(text:'${p['current_retirement_savings']??0}'),monthly=TextEditingController(text:'${p['monthly_retirement_contribution']??''}'),rate=TextEditingController(text:'${p['expected_annual_return']??5}'),infl=TextEditingController(text:'${p['inflation_rate']??3}'),desired=TextEditingController(text:'${p['desired_monthly_retirement_income']??''}'),years=TextEditingController(text:'${p['retirement_years']??20}');
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Retirement assumptions'),content:SingleChildScrollView(child:Column(children:[_num('Current age',age),_num('Retirement age',ret),_num('Current retirement savings',current),_num('Monthly contribution',monthly),_num('Expected annual return %',rate),_num('Inflation %',infl),_num('Desired monthly retirement income',desired),_num('Years in retirement',years)])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Save'))]));
    if(ok==true){try{await _service.update({'current_age':int.tryParse(age.text),'retirement_age':int.tryParse(ret.text),'current_retirement_savings':double.tryParse(current.text)??0,'monthly_retirement_contribution':monthly.text.trim().isEmpty?null:double.tryParse(monthly.text),'expected_annual_return':double.tryParse(rate.text)??5,'inflation_rate':double.tryParse(infl.text)??3,'desired_monthly_retirement_income':desired.text.trim().isEmpty?null:double.tryParse(desired.text),'retirement_years':int.tryParse(years.text)??20});await _load();}on ApiException catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.message)));}}
  }
  Widget _num(String l,TextEditingController c)=>Padding(padding:const EdgeInsets.only(bottom:8),child:TextField(controller:c,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:l,border:const OutlineInputBorder())));
}
