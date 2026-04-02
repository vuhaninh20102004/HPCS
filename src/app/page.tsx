import { Navbar } from "@/components/navbar";
import { Footer } from "@/components/footer";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import {
  Car,
  ParkingSquare,
  History,
  Camera,
  ArrowRight,
  TrendingUp,
  TrendingDown,
} from "lucide-react";
import Link from "next/link";

const stats = [
  {
    title: "Tổng phương tiện",
    value: "0",
    description: "đang trong bãi",
    icon: Car,
    trend: "up" as const,
    href: "/vehicles",
  },
  {
    title: "Chỗ đỗ trống",
    value: "0",
    description: "/ 0 tổng",
    icon: ParkingSquare,
    trend: "down" as const,
    href: "/parking-slots",
  },
  {
    title: "Lượt ra/vào hôm nay",
    value: "0",
    description: "lượt",
    icon: History,
    trend: "up" as const,
    href: "/history",
  },
  {
    title: "Camera hoạt động",
    value: "0",
    description: "/ 0 thiết bị",
    icon: Camera,
    trend: "up" as const,
    href: "/camera",
  },
];

export default function HomePage() {
  return (
    <>
      <Navbar />
      <main className="flex-1 container mx-auto px-4 py-6">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-heading font-bold tracking-tight">
            Dashboard
          </h1>
          <p className="mt-1 text-muted-foreground">
            Tổng quan hệ thống quản lý đỗ xe
          </p>
        </div>

        {/* Stats Grid */}
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {stats.map((stat) => (
            <Card key={stat.title}>
              <CardHeader className="flex flex-row items-center justify-between pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground">
                  {stat.title}
                </CardTitle>
                <stat.icon className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="flex items-baseline gap-2">
                  <span className="text-2xl font-bold">{stat.value}</span>
                  <span className="text-xs text-muted-foreground">
                    {stat.description}
                  </span>
                </div>
                <div className="mt-2 flex items-center justify-between">
                  <Badge
                    variant={stat.trend === "up" ? "default" : "secondary"}
                    className="gap-1 text-xs"
                  >
                    {stat.trend === "up" ? (
                      <TrendingUp className="h-3 w-3" />
                    ) : (
                      <TrendingDown className="h-3 w-3" />
                    )}
                    --
                  </Badge>
                  <Button variant="ghost" size="sm" asChild>
                    <Link href={stat.href} className="gap-1">
                      Chi tiết
                      <ArrowRight className="h-3 w-3" />
                    </Link>
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>

        <Separator className="my-8" />

        {/* Quick Actions */}
        <div>
          <h2 className="text-xl font-heading font-semibold tracking-tight mb-4">
            Thao tác nhanh
          </h2>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            <Button variant="outline" className="h-auto py-4 justify-start gap-3" asChild>
              <Link href="/vehicles">
                <Car className="h-5 w-5" />
                <div className="text-left">
                  <div className="font-medium">Quản lý phương tiện</div>
                  <div className="text-xs text-muted-foreground">
                    Thêm, sửa, xóa thông tin xe
                  </div>
                </div>
              </Link>
            </Button>
            <Button variant="outline" className="h-auto py-4 justify-start gap-3" asChild>
              <Link href="/parking-slots">
                <ParkingSquare className="h-5 w-5" />
                <div className="text-left">
                  <div className="font-medium">Quản lý bãi đỗ</div>
                  <div className="text-xs text-muted-foreground">
                    Xem trạng thái chỗ đỗ
                  </div>
                </div>
              </Link>
            </Button>
            <Button variant="outline" className="h-auto py-4 justify-start gap-3" asChild>
              <Link href="/camera">
                <Camera className="h-5 w-5" />
                <div className="text-left">
                  <div className="font-medium">Giám sát camera</div>
                  <div className="text-xs text-muted-foreground">
                    Xem feed camera trực tiếp
                  </div>
                </div>
              </Link>
            </Button>
          </div>
        </div>
      </main>
      <Footer />
    </>
  );
}
