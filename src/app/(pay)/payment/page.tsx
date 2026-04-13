"use client";

import Image from "next/image";
import { useState } from "react";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Copy, QrCode, RefreshCcw } from "lucide-react";

type PaymentQrData = {
  provider: "vietqr";
  qrImageUrl: string;
  bankCode: string;
  accountNumber: string;
  accountName: string | null;
  transferContent: string;
  amount: number;
  currency: string;
};

type PaymentResponse = {
  id: number;
  invoiceNumber: string;
  plateNumber: string | null;
  vehicleType: "car" | "motorcycle" | "truck";
  amount: number;
  currency: string;
  paymentMethod: "bank_transfer" | "cash" | "card";
  status: "pending" | "paid" | "failed";
  createdAt: string;
  paidAt: string | null;
  syncedAt: string | null;
  paymentQr: PaymentQrData | null;
  paymentQrError: string | null;
};

function formatCurrency(value: number): string {
  return new Intl.NumberFormat("vi-VN", {
    style: "currency",
    currency: "VND",
    maximumFractionDigits: 0,
  }).format(value);
}

export default function PaymentPage() {
  const [plateNumber, setPlateNumber] = useState("");
  const [vehicleType, setVehicleType] = useState<
    "car" | "motorcycle" | "truck"
  >("car");
  const [paymentMethod, setPaymentMethod] = useState<
    "bank_transfer" | "cash" | "card"
  >("bank_transfer");
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [payment, setPayment] = useState<PaymentResponse | null>(null);

  const createPendingPayment = async () => {
    setLoading(true);
    setMessage(null);

    try {
      const response = await fetch("/api/payments", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          plateNumber: plateNumber.trim() || undefined,
          vehicleType,
          paymentMethod,
        }),
      });

      const payload = (await response.json()) as {
        data?: PaymentResponse;
        message?: string;
      };

      if (!response.ok || !payload.data) {
        throw new Error(payload.message ?? "Không thể tạo payment pending");
      }

      setPayment(payload.data);
      setMessage(payload.message ?? "Tạo payment pending thành công");
    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : "Không thể tạo payment pending",
      );
    } finally {
      setLoading(false);
    }
  };

  const refreshPaymentStatus = async () => {
    if (!payment?.invoiceNumber) {
      return;
    }

    setLoading(true);
    setMessage(null);

    try {
      const response = await fetch(
        `/api/payments?invoice_number=${encodeURIComponent(payment.invoiceNumber)}`,
        {
          method: "GET",
          cache: "no-store",
        },
      );

      const payload = (await response.json()) as {
        data?: PaymentResponse | null;
        message?: string;
      };

      if (!response.ok) {
        throw new Error(payload.message ?? "Không thể làm mới trạng thái");
      }

      if (payload.data) {
        setPayment(payload.data);
        setMessage("Đã làm mới trạng thái payment");
      } else {
        setMessage(payload.message ?? "Không tìm thấy payment");
      }
    } catch (error) {
      setMessage(
        error instanceof Error ? error.message : "Không thể làm mới trạng thái",
      );
    } finally {
      setLoading(false);
    }
  };

  const copyTransferContent = async () => {
    if (!payment?.paymentQr?.transferContent) {
      return;
    }

    try {
      await navigator.clipboard.writeText(payment.paymentQr.transferContent);
      setMessage("Đã copy nội dung chuyển khoản");
    } catch {
      setMessage("Không thể copy nội dung chuyển khoản");
    }
  };

  return (
    <main className="min-h-screen bg-muted/20 p-4 sm:p-8">
      <div className="mx-auto grid max-w-5xl gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <QrCode className="h-5 w-5" />
              QR Thanh Toán
            </CardTitle>
            <CardDescription>
              QR thật theo chuẩn VietQR, nội dung chuyển khoản là invoice để hệ
              thống đối soát XGate.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {payment?.paymentMethod === "bank_transfer" &&
              payment.paymentQr && (
                <div className="rounded-xl border bg-white p-4">
                  <Image
                    src={payment.paymentQr.qrImageUrl}
                    alt={`VietQR ${payment.invoiceNumber}`}
                    width={280}
                    height={280}
                    unoptimized
                    className="mx-auto h-[280px] w-[280px] max-w-full object-contain"
                  />
                </div>
              )}

            {payment?.paymentMethod !== "bank_transfer" && (
              <div className="rounded-xl border border-dashed bg-background px-4 py-8 text-center text-sm text-muted-foreground">
                QR chỉ hiển thị với phương thức bank transfer.
              </div>
            )}

            {payment?.paymentMethod === "bank_transfer" &&
              !payment.paymentQr && (
                <div className="rounded-xl border border-dashed bg-background px-4 py-8 text-center text-sm text-destructive">
                  {payment.paymentQrError ?? "Chưa tạo được QR thanh toán"}
                </div>
              )}

            <div className="space-y-2">
              <p className="text-sm text-muted-foreground">
                Nội dung chuyển khoản
              </p>
              <p className="rounded-md border bg-background px-3 py-2 text-sm font-medium">
                {payment?.paymentQr?.transferContent ??
                  payment?.invoiceNumber ??
                  "HPCS-... (sinh sau khi bấm tạo payment)"}
              </p>
            </div>

            <div className="space-y-2">
              <p className="text-sm text-muted-foreground">Số tiền</p>
              <p className="text-xl font-bold">
                {formatCurrency(payment?.amount ?? 0)}
              </p>
            </div>

            {payment?.paymentQr && (
              <div className="space-y-2 text-sm">
                <p className="text-muted-foreground">Thông tin nhận tiền</p>
                <div className="rounded-lg border bg-background p-3 space-y-1">
                  <p>
                    Ngân hàng:{" "}
                    <span className="font-medium uppercase">
                      {payment.paymentQr.bankCode}
                    </span>
                  </p>
                  <p>
                    Số tài khoản:{" "}
                    <span className="font-medium">
                      {payment.paymentQr.accountNumber}
                    </span>
                  </p>
                  <p>
                    Chủ tài khoản:{" "}
                    <span className="font-medium">
                      {payment.paymentQr.accountName ?? "N/A"}
                    </span>
                  </p>
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Tạo payment pending</CardTitle>
            <CardDescription>
              Chủ động tạo payment để test luồng đồng bộ XGate (invoice_number
              nằm trong content giao dịch).
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <p className="text-sm text-muted-foreground">
                Biển số (tuỳ chọn)
              </p>
              <Input
                placeholder="Ví dụ: 30A-123.45"
                value={plateNumber}
                onChange={(e) => setPlateNumber(e.target.value)}
              />
            </div>

            <div className="grid gap-3 sm:grid-cols-2">
              <div className="space-y-2">
                <p className="text-sm text-muted-foreground">Loại xe</p>
                <Select
                  value={vehicleType}
                  onValueChange={(value) =>
                    setVehicleType(value as "car" | "motorcycle" | "truck")
                  }
                >
                  <SelectTrigger className="w-full">
                    <SelectValue placeholder="Chọn loại xe" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="motorcycle">Motorcycle</SelectItem>
                    <SelectItem value="car">Car</SelectItem>
                    <SelectItem value="truck">Truck</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <p className="text-sm text-muted-foreground">Phương thức</p>
                <Select
                  value={paymentMethod}
                  onValueChange={(value) =>
                    setPaymentMethod(value as "bank_transfer" | "cash" | "card")
                  }
                >
                  <SelectTrigger className="w-full">
                    <SelectValue placeholder="Chọn phương thức" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="bank_transfer">Bank Transfer</SelectItem>
                    <SelectItem value="cash">Cash</SelectItem>
                    <SelectItem value="card">Card</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div className="flex flex-wrap gap-2">
              <Button onClick={createPendingPayment} disabled={loading}>
                {loading ? "Đang tạo..." : "Tạo payment"}
              </Button>
              <Button
                variant="outline"
                className="gap-2"
                onClick={copyTransferContent}
                disabled={loading || !payment?.paymentQr?.transferContent}
              >
                <Copy className="h-4 w-4" />
                Copy nội dung CK
              </Button>
              <Button
                variant="outline"
                className="gap-2"
                onClick={refreshPaymentStatus}
                disabled={loading || !payment}
              >
                <RefreshCcw className="h-4 w-4" />
                Làm mới trạng thái
              </Button>
            </div>

            {message && (
              <p className="text-sm text-muted-foreground">{message}</p>
            )}

            {payment && (
              <div className="rounded-lg border p-3 space-y-2 text-sm">
                <div className="flex items-center justify-between">
                  <span className="text-muted-foreground">Invoice</span>
                  <span className="font-medium">{payment.invoiceNumber}</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-muted-foreground">Trạng thái</span>
                  <Badge
                    variant={
                      payment.status === "paid"
                        ? "default"
                        : payment.status === "failed"
                          ? "destructive"
                          : "secondary"
                    }
                  >
                    {payment.status}
                  </Badge>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-muted-foreground">Tạo lúc</span>
                  <span>
                    {new Date(payment.createdAt).toLocaleString("vi-VN")}
                  </span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-muted-foreground">Synced lúc</span>
                  <span>
                    {payment.syncedAt
                      ? new Date(payment.syncedAt).toLocaleString("vi-VN")
                      : "Chưa sync"}
                  </span>
                </div>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </main>
  );
}
