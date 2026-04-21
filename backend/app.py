from flask import Flask, request, send_file, jsonify
from flask_cors import CORS
from jinja2 import Environment, FileSystemLoader
from weasyprint import HTML
import os
import uuid

app = Flask(__name__)
CORS(app)

# ------------------------------------------------
# Base directory
# ------------------------------------------------

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TEMPLATE_DIR = os.path.join(BASE_DIR, "templates")
ASSETS_DIR = os.path.join(BASE_DIR, "assets")
OUTPUT_DIR = os.path.join(BASE_DIR, "generated_quotes")

os.makedirs(OUTPUT_DIR, exist_ok=True)

env = Environment(loader=FileSystemLoader(TEMPLATE_DIR))


# ------------------------------------------------
# Home route
# ------------------------------------------------

@app.route("/")
def home():
    return "Quote Generator API Running"


# ------------------------------------------------
# Generate Quote API
# ------------------------------------------------

@app.route("/generate-quote", methods=["POST"])
def generate_quote():

    try:

        data = request.get_json()
        print("Received JSON:")
        print(data)

        if not data:
            return jsonify({"error": "No JSON received"}), 400

        date = data.get("date", "")
        company = data.get("company", "")
        address = data.get("address", "")
        subject = data.get("subject", "")

        components = data.get("components", [])

        formatted_components = []
        total_cost = 0

        # -----------------------------
        # Process Components
        # -----------------------------

        for item in components:

            description = item.get("description", "")
            machine = item.get("machine", "")

            try:
                raw_amount = item.get("amount", "0")

                # REMOVE COMMAS FROM AMOUNT STRING
                if isinstance(raw_amount, str):
                    cleaned_amount = raw_amount.replace(",", "")
                else:
                    cleaned_amount = str(raw_amount)

                amount = int(cleaned_amount)

            except Exception as e:
                print("Amount conversion error:", e)
                amount = 0

            total_cost += amount

            formatted_components.append({
                "description": description,
                "amount": f"{amount:,}",
                "machine": machine
            })

        # -----------------------------
        # Prepare Template Data
        # -----------------------------

        template_data = {
            "date": date,
            "company": company,
            "address": address,
            "subject": subject,
            "components": formatted_components,
            "total_cost": f"{total_cost:,}",

            "logo": f"file:///{ASSETS_DIR}/logo.png",
            "watermark": f"file:///{ASSETS_DIR}/bg.png",
            "signature": f"file:///{ASSETS_DIR}/sign.png"
        }

        # -----------------------------
        # Render Template
        # -----------------------------

        template = env.get_template("quote_template.html")

        html_content = template.render(template_data)

        # -----------------------------
        # Generate PDF
        # -----------------------------

        file_id = str(uuid.uuid4())[:8]

        pdf_path = os.path.join(OUTPUT_DIR, f"quote_{file_id}.pdf")

        HTML(string=html_content, base_url=BASE_DIR).write_pdf(pdf_path)

        return send_file(pdf_path, mimetype="application/pdf")

    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ------------------------------------------------

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)