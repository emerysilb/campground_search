import 'dart:async';
import 'dart:convert';

import 'package:aws_lambda_dart_runtime/aws_lambda_dart_runtime.dart';
import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';
import 'package:sendgrid_mailer/sendgrid_mailer.dart';

final String to_email = 'user@user.com';
final String from_email = 'user@user.com';
final String sendgrid_api_key = 'SENDGRID_API_KEY';

DateTime startDate = DateTime.parse('2021-07-20');
DateTime endDate = DateTime.parse('2021-08-05');
String search_date = '2021-07-01';
final campgrounds = [232447, 232450, 232446, 232453, 232448];
Map<int, String> campNames = {
  232447: 'Upper Pines',
  232450: 'Lower Pines',
  232446: 'Wowona',
  232453: 'Bridalveil',
  232448: 'Tuolumne Meadows',
};

void main() async {
  /// This demo's handling an ALB request.
  ///
  ///
  await check_yosemite();
  final Handler<AwsALBEvent> helloALB = (context, event) async {
    String result = await check_yosemite();
    final response = result;

    /// Returns the response to the ALB.
    return InvocationResult(
        context.requestId, AwsALBResponse.fromString(response));
  };

  final Handler<AwsCloudwatchEvent> runLambda = (context, event) async {
    String result = await check_yosemite();
    final response = result;
    return InvocationResult(context.requestId, result);
  };

  /// The Runtime is a singleton.
  /// You can define the handlers as you wish.
  Runtime()
    ..registerHandler<AwsCloudwatchEvent>("hello.ACE", runLambda)
    ..invoke();
}

Future<String> check_yosemite() async {
  Map sites = {};

  // final campgrounds = [232269];

  for (final campground in campgrounds) {
    var request = http.Request(
        'GET',
        Uri.parse(
            'https://www.recreation.gov/api/camps/availability/campground/${campground.toString()}/month?start_date=${search_date}T00%3A00%3A00.000Z'));
    List<AvailableSite> availablesites = await request_data(request);
    List<String> sitenames = [];
    if (availablesites.isNotEmpty) {
      // print(campNames[campground]);

      availablesites.forEach((element) {
        // print('site: ' + element.siteName + '    date:' + element.siteDate);
        sitenames.add('Site: ' +
            element.siteName +
            ' Date:' +
            element.siteDate.split(" ")[0] +
            '  ');
      });
      sites[campNames[campground]] = sitenames;
    }

    // print('processed: ' + campNames[campground]!);
  }
  if (sites.length > 0) {
    print(sites.toString());
    ;
    emailme(sites.toString());
    return 'Campsites found and emailed';
  }
  return 'Nothing found';
  // print(sites.length);
}

Future<List<AvailableSite>> request_data(request) async {
  bool responseFailure = false;
  List<AvailableSite> sites = [];
  final response = await retry(
    () async {
      responseFailure = false;
      http.StreamedResponse response = await request.send();
      if (response.statusCode == 200) {
        var raw_data = await response.stream.bytesToString();
        var parsed = json.decode(raw_data);
        Map<String, dynamic> campsites = parsed['campsites'];
        List<AvailableSite> availabilities = process_data(campsites);
        if (availabilities.isNotEmpty) {
          sites = availabilities;
        }
      } else {
        print(response.reasonPhrase);
        responseFailure = true;
        // throw Error()
      }
    },
    retryIf: (e) => responseFailure,
  );
  return sites;
}

List<AvailableSite> process_data(Map<String, dynamic> data) {
  List<AvailableSite> sites = [];
  data.forEach((key, campsite) {
    Map<String, dynamic> availabilities = campsite['availabilities'];

    availabilities.forEach(
      (key, value) {
        DateTime site_date = DateTime.parse(key);
        if (site_date.isAfter(startDate) &&
            site_date.isBefore(endDate) &&
            value == 'Available') {
          sites.add(
              AvailableSite(campsite['site'].toString(), site_date.toString()));
        }
      },
    );
  });
  return sites;
}

class AvailableSites {
  List<AvailableSite> campsites;
  AvailableSites(this.campsites);
}

class AvailableSite {
  final String siteName;
  final String siteDate;

  AvailableSite(
    this.siteName,
    this.siteDate,
  );

  Map<String, dynamic> toMap() {
    return {
      'siteName': siteName,
      'siteDate': siteDate,
    };
  }

  factory AvailableSite.fromMap(Map<String, dynamic> map) {
    return AvailableSite(
      map['siteName'],
      map['siteDate'],
    );
  }

  String toJson() => json.encode(toMap());

  factory AvailableSite.fromJson(String source) =>
      AvailableSite.fromMap(json.decode(source));
}

emailme(String campsites) async {
  final mailer = Mailer(sendgrid_api_key);
  final toAddress = Address(to_email);
  final fromAddress = Address(from_email);
  final content = Content('text/plain', campsites);
  final subject = 'Campsites found!';
  final personalization = Personalization([toAddress]);

  final email =
      Email([personalization], fromAddress, subject, content: [content]);
  await mailer.send(email).then((result) {
    print('email sent!');
    // ...
  });
}
