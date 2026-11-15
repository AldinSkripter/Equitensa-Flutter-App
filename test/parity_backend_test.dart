@TestOn('vm')
@Timeout(Duration(minutes: 5))
library;
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:equitensa/data/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Data=Map<String,dynamic>;
Data obj(dynamic v)=>Map<String,dynamic>.from(v as Map);
class _PacedClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async { await Future<void>.delayed(const Duration(seconds: 1)); return _inner.send(request); }
  @override
  void close() => _inner.close();
}
void main(){
  late bool available;
  setUpAll(()async{HttpOverrides.global=null;available=false;try{final c=HttpClient()..connectionTimeout=const Duration(seconds:2);final r=await(await c.getUrl(Uri.parse('http://localhost:3000/api/health'))).close();final j=jsonDecode(await utf8.decoder.bind(r).join());available=r.statusCode==200&&j['mode']=='demo';c.close();}catch(_){} });
  test('Pay annual import, workflow, rights, criteria, national report and prepared export share one backend',()async{
    if(!available){markTestSkipped('Isolated local demo backend required');return;}
    final api=ApiClient(baseUrl:'http://localhost:3000',persist:false,client:_PacedClient());
    await api.postJson('/demo',{'country':'DE'});
    const fields=['internal_id','gender','job_title','worker_category','base_annual','bonuses_annual','paid_hours_annual','hours_per_week'];
    final csv=[fields.join(';'),for(var i=0;i<12;i++) 'P$i;${i<6?'M':'F'};Engineer;Engineering;60000;1000;1920;40'].join('\n');
    final payload={'year':2026,'csv':csv};
    final preview=await api.postJson('/import/preview',payload);
    expect(preview['count'],12);
    final mapping={for(final field in fields)field:field};
    final quality=await api.postJson('/import/quality',{...payload,'mapping':mapping,'decimalSeparator':'.'});
    expect(obj(quality['summary'])['errors'],0);
    await api.postJson('/import',{...payload,'mapping':mapping,'decimalSeparator':'.','contextConfirmed':true});
    final analysis=await api.getJson('/analysis?year=2026'),context=await api.getJson('/employer-context?year=2026');
    expect(obj(analysis['analysis'])['count'],12);
    final workflow={'snapshotId':context['snapshotId'],'profile':{'legalName':'Contract Test GmbH','headcount':12,'payrollComplete':true},'classification':{'Engineering':{for(final f in ['skills','effort','responsibility','conditions'])f:'Documented objective criterion'}},'criteriaAgreement':{'status':'no_representatives','note':'No representatives exist'},'jobEvaluation':{'mode':'documented','methodology':'Documented evaluation','reference':'Internal evidence 1','assessedBy':'Test reviewer','assessedOn':'2026-01-01','genderNeutralConfirmed':true,'categories':{'Engineering':{'rationale':'Same work','evidence':'Role descriptions','roles':[]}}},'reviews':{'Engineering':{'explanation':'Equal pay','justified':true}},'approval':{'manager':'Test manager','representatives':'No representatives; documented consultation','confirmed':true,'consulted':true},'assessment':{'previousMeasures':'No previous assessment','jointReviewConfirmed':true,'leaveOutcomes':{'Engineering':{'applicable':false,'note':'No eligible returners'}}},'reportingDate':'2026-01-01'};
    final saved=await api.postJson('/workflow',{'year':2026,'workflow':workflow});
    expect(obj(saved['readiness'])['ready'],true);
    expect(obj(obj(await api.getJson('/workflow?year=2026'))['workflow'])['snapshotId'],context['snapshotId']);
    await api.postJson('/pay-criteria',{'ranges':{'Engineering':{'min':50000,'max':70000,'agreement':'Internal pay structure'}},'progression':'Objective development criteria'});
    expect((await api.postBytes('/pay-criteria/document',{'year':2026,'kind':'criteria','format':'pdf'})).take(4),[37,80,68,70]);
    final request=await api.postJson('/requests',{'requesterLabel':'Synthetic worker','receivedOn':'2026-01-01','channel':'worker','kind':'information','note':'Contract test'});
    final requestId=obj(request['request'])['id'];
    final answer=await api.postJson('/requests/$requestId/answer',{'year':2026,'internalId':'P0','format':'json'});
    expect(obj(obj(answer['answer'])['worker'])['category'],'Engineering');
    await api.postJson('/requests/$requestId/close',{'answeredOn':'2026-01-02','summary':'Response delivered outside app'});
    await api.postJson('/rights-notice',{'year':2026,'sentOn':'2026-01-01','contact':'test@example.invalid'});
    expect((await api.postBytes('/rights-notice/document',{'year':2026,'contact':'test@example.invalid','format':'pdf'})).length,greaterThan(100));
    await api.postJson('/employer-controls',{'year':2026,'document':{'snapshotId':context['snapshotId'],'records':{'scope':{'status':'recorded','owner':'Reviewer','reviewedOn':'2026-01-01','evidence':'Confirmed personnel scope'}}}});
    expect((await api.getBytes('/employer-controls/pdf?year=2026')).length,greaterThan(100));
    expect((await api.getBytes('/evidence/json?year=2026')).length,greaterThan(100));
    await api.postJson('/national-report',{'year':2026,'confirmed':true,'cycle':'three','firstReport':true,'equalityMeasures':'Documented measures','equalityEffects':'Recorded results','equalPayMeasures':'Equal pay review','counts':{'men':{'fullTime':6,'partTime':0},'women':{'fullTime':6,'partTime':0}}});
    expect((await api.postBytes('/national-report/document',{'year':2026,'format':'pdf'})).length,greaterThan(100));
    final billing=await api.getJson('/billing');expect(billing['mode'],'sandbox');
    final order=await api.postJson('/billing/checkout',{'plan':'prepare','interval':'annual','accepted':true,'contractVersion':billing['contractVersion']});
    await api.postJson('/billing/sandbox-confirm',{'orderId':obj(order['order'])['id']});
    expect((await api.getBytes('/reports/pdf?year=2026&audience=internal&prepared=true')).length,greaterThan(100));
    expect((await api.getBytes('/reports/pdf?year=2026&audience=internal&prepared=true&type=assessment')).length,greaterThan(100));
    for(final format in ['csv','xml','txt','xlsx','json','html']){expect((await api.getBytes('/reports/$format?year=2026&audience=workers')).length,greaterThan(50));}
    final cancellation=await api.getJson('/billing/cancellation');expect(cancellation['minimumMonths'],12);
    await api.postJson('/billing/cancellation',{'confirm':true,'orderId':cancellation['orderId']});
    final key=await api.postJson('/integrations/keys',{'label':'Contract test'});expect(key['key'],isNotEmpty);await api.postJson('/integrations/keys/${obj(key['record'])['id']}/revoke',{});
    await api.postJson('/company/brand',{'displayName':'Shared app and web','logo':''});expect(obj((await api.getJson('/company/brand'))['brand'])['displayName'],'Shared app and web');
    final policy={'purpose':'Contract test cleanup','legalBasis':'Synthetic demo data','retentionMonths':1,'owner':'Test operator','reviewedOn':'2026-01-01','backupProcedure':'Ephemeral synthetic test company','holds':[],'confirmed':true};
    await api.postJson('/data-retention',{'policy':policy});
    final inventory=await api.getJson('/data-retention?year=2026');
    final deletion=await api.postJson('/data-retention/delete-year',{'year':2026,'fingerprint':inventory['fingerprint'],'confirmation':'DE 2026 DELETE','legalReviewConfirmed':true,'exceptionReviewed':true,'exceptionReason':'Synthetic automated test data'});
    expect(deletion['receipt'],isA<Map>());
    await api.postJson('/auth/logout',{});

  });
  test('Finance advanced actions use revisions, frozen originals, bank allocation and full archives',()async{
    if(!available){markTestSkipped('Isolated local demo backend required');return;}
    final api=ApiClient(baseUrl:'http://localhost:3000',persist:false,client:_PacedClient());await api.postJson('/demo',{'country':'DE'});
    var state=obj((await api.getJson('/finance'))['state']);
    Future<Data> mutate(String path,Data body)async{final result=await api.postJson('/finance/$path',{...body,'revision':state['revision']});state=obj(result['state']);return obj(result['result']??{});}
    await mutate('settings',{'country':'DE','confirmCountry':true,'name':'Synthetic Supplier','address':'Teststrasse 1','postalCode':'10115','city':'Berlin','vatId':'DE123456789','iban':'DE89370400440532013000','email':'supplier@example.invalid','accent':'#7451f8'});
    final c=await mutate('contacts',{'name':'Synthetic Buyer','address':'Teststrasse 2','postalCode':'10115','city':'Berlin','country':'DE','vatId':'DE987654321','email':'buyer@example.invalid','business':true,'publicBody':false});
    for (final country in ['BA','US','CH','FR']) { final foreign = await mutate('contacts', {'name':'Foreign $country','country':country,'business':true,'publicBody':false}); expect(foreign['country'],country); }
    final product=await mutate('products',{'name':'Consulting','sku':'TEST-1','unit':'h','unitPrice':'100.00','rate':'19'});
    await mutate('products/${product['id']}',{...product,'archived':true});
    final draft={'kind':'invoice','reference':'PO-2026-1','einvoice':{'contactName':'Test Person','contactPhone':'+49301234567'},'contactId':c['id'],'issueDate':'2026-01-01','serviceDate':'2026-01-01','dueDate':'2026-01-15','lines':[{'description':'Consulting','quantity':'1','unit':'h','unitPrice':'100.00','rate':'19','discountPercent':'0'}]};
    final document=await mutate('documents',draft),id=document['id'];
    final series=await mutate('recurring',{'documentId':id,'startDate':'2026-11-01','interval':1,'paymentDays':14,'name':'Monthly consulting','autoOnOpen':true});
    await mutate('recurring/run',{});await mutate('recurring/${series['id']}/toggle',{});
    final link=await mutate('documents/$id/share',{'enabled':true,'days':7});expect(link['url'],contains('/shared-finance/'));await mutate('documents/$id/share',{'enabled':false});
    final check=await api.getJson('/finance/documents/$id/issue-check?format=xrechnung');expect(check['ready'],true, reason: '$check');
    final issued=await mutate('documents/$id/issue',{'format':'xrechnung','confirm':true,'taxScopeConfirmed':true,'requestKey':'contracttestissuerequest000000001'});expect(issued['originals'],isNotEmpty);
    final original=(issued['originals'] as List).cast<Map>().firstWhere((f)=>f['extension']=='pdf');
    expect((await api.getBytes('/finance/documents/$id/originals/${original['id']}')).take(4),[37,80,68,70]);
    expect((await api.getBytes('/finance/documents/$id/bundle.zip')).take(2),[80,75]);
    expect((await api.postBytes('/finance/documents/$id/email-draft',{'recipient':'buyer@example.invalid'})).length,greaterThan(100));
    await mutate('documents/$id/delivery',{'channel':'email','recipient':'buyer@example.invalid','reference':'Externally delivered synthetic record','sentAt':DateTime.now().toUtc().toIso8601String(),'confirm':true});
    final bank={'account':'contract-bank','csv':'id;date;amount;description\nB1;2026-01-16;119.00;Synthetic payment','delimiter':';','mapping':{'externalId':'id','bookedOn':'date','amount':'amount','description':'description'}};
    final preview=await api.postJson('/finance/bank/preview',bank);await mutate('bank/import',bank);
    await mutate('bank/${(preview['transactions'] as List).first['id']}/allocate',{'documentId':id,'amount':'119.00','confirm':true});
    expect((await api.getJson('/finance/receivables'))['outstandingCents'],0);
    final offer=await mutate('documents',{...draft,'kind':'offer'});await mutate('documents/${offer['id']}/offer-status',{'status':'sent','validUntil':'2026-12-31','note':'Externally sent'});await mutate('documents/${offer['id']}/offer-status',{'status':'accepted','note':'Accepted outside app'});await mutate('documents/${offer['id']}/convert',{});
    final expense=await mutate('expenses',{'supplier':'Test Vendor','reference':'EXP-1','incurredOn':'2026-01-01','amount':'25.00','category':'office'});await mutate('expenses/${expense['id']}',{'supplier':'Test Vendor','reference':'EXP-1','incurredOn':'2026-01-01','amount':'26.00','category':'office','note':'Edited'});
    final design=await mutate('designs',{'name':'Saved test design','appearance':{'accent':'#7451f8','design':{'template':'minimal'}}});await mutate('designs/${design['id']}/remove',{});
    for(final kind in ['documents','payments','expenses','contacts','products']){expect((await api.getBytes('/finance/export.csv?kind=$kind')).length,greaterThan(10));}
    expect((await api.getBytes('/finance/archive.zip')).take(2),[80,75]);expect((await api.getJson('/finance/export'))['format'],'equitensa-finance-v1');
    final fresh=obj((await api.getJson('/finance'))['state']);expect(fresh['revision'],state['revision']);
    await api.postJson('/auth/logout',{});
  });
  test('Monthly payroll stages, classifies and finalizes through versioned web routes', () async {
    if (!available) { markTestSkipped('Isolated local demo backend required'); return; }
    final api = ApiClient(baseUrl: 'http://localhost:3000', persist: false, client: _PacedClient());
    await api.postJson('/demo', {'country':'AT'});
    final hr = {'year':2026,'kind':'hr','csv':'internal_id;gender;job_title;worker_category;hours_per_week;first_month;last_month\nM1;M;Engineer;Engineering;40;1;1','mapping':{for(final k in ['internal_id','gender','job_title','worker_category','hours_per_week','first_month','last_month']) k:k}};
    final preview = await api.postJson('/payroll/preview', hr); expect(preview['count'],1);
    final staged = await api.postJson('/payroll/stage',{...hr,'version':0,'contextConfirmed':true,'decimalSeparator':'.'});
    final transactions = {'year':2026,'kind':'transactions','source':'test-payroll','csv':'transaction_id;internal_id;period;pay_code;amount;currency;paid_hours\nT1;M1;2026-01;BASE;5000;EUR;160','mapping':{for(final k in ['transaction_id','internal_id','period','pay_code','amount','currency','paid_hours']) k:k}};
    final stagedTransactions = await api.postJson('/payroll/stage',{...transactions,'version':staged['version'],'contextConfirmed':true,'decimalSeparator':'.'});
    final codes = (stagedTransactions['codes'] as List).map((c)=>{...obj(c),'classification':'ordinary','reason':'Verified ordinary basic remuneration'}).toList();
    final classified = await api.postJson('/payroll/codes',{'year':2026,'version':stagedTransactions['version'],'codes':codes});expect(classified['ready'],true);
    final finalized = await api.postJson('/payroll/finalize',{'year':2026,'version':classified['version'],'contextConfirmed':true});expect(obj(finalized['snapshot'])['count'],1);
    final analysis = await api.getJson('/analysis?year=2026');expect(obj(analysis['analysis'])['count'],1);expect(obj(analysis['analysis'])['suppressed'],true);
    await api.postJson('/auth/logout',{});
  });

}
