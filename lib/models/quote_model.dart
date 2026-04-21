class QuoteModel {

  String date;
  String company;
  String address;
  String subject;

  List<Map<String,String>> components;

  QuoteModel({
    required this.date,
    required this.company,
    required this.address,
    required this.subject,
    required this.components
  });

  Map<String,dynamic> toJson(){

    return {
      "date":date,
      "company":company,
      "address":address,
      "subject":subject,
      "components":components
    };

  }

}